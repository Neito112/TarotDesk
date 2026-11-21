import 'dart:convert';

import 'github_service.dart';
import '../../logic/auth_provider.dart';
import '../models/tarot_card.dart';
import '../models/tarot_deck.dart';

/// One deck file in the shared server library (`server/decks/`).
///
/// [name] is the deck file name without `.json`; [path] is e.g.
/// `server/decks/<slug>.json`. [author] and [cardCount] are left null by
/// [ServerDeckService.listSharedDecks] (filled in by a fetch when needed).
class SharedDeckInfo {
  final String name;
  final String path;
  final String? author;
  final int? cardCount;

  const SharedDeckInfo({
    required this.name,
    required this.path,
    this.author,
    this.cardCount,
  });
}

/// One open deck-submission pull request (branch `submit/...`).
class OpenSubmission {
  final int number;
  final String title;
  final String author;
  final String url;
  final String branch;

  const OpenSubmission({
    required this.number,
    required this.title,
    required this.author,
    required this.url,
    required this.branch,
  });
}

/// Shared decks and user submissions, stored as JSON files in the
/// Neito112/TarotDesk repo (`server/decks/` and `server/submissions/`).
///
/// Users submit a deck by opening a pull request from a `submit/...`
/// branch; the owner (admin) merges to approve or closes to reject.
/// Any network/API failure throws a [GithubException] to the caller.
class ServerDeckService {
  final AuthProvider auth;

  /// Instance of the GitHub API client (zero-arg constructor per contract).
  final GithubService _github = GithubService();

  ServerDeckService(this.auth);

  static const String owner = 'Neito112';
  static const String repo = 'TarotDesk';
  static const String sharedDir = 'server/decks';
  static const String submissionsDir = 'server/submissions';
  static const String baseBranch = 'main';

  String _token() {
    final token = auth.token;
    if (token == null || token.isEmpty) {
      throw GithubException('Not logged in');
    }
    return token;
  }

  String _login() {
    final login = auth.user?.login;
    if (login == null || login.isEmpty) {
      throw GithubException('Not logged in');
    }
    return login;
  }

  /// Shared decks visible to all users. No extra API calls are made here:
  /// [SharedDeckInfo.author] and [SharedDeckInfo.cardCount] stay null.
  Future<List<SharedDeckInfo>> listSharedDecks() async {
    final entries = await _github.listRepoContents(_token(), sharedDir);
    return _jsonFiles(entries, sharedDir);
  }

  /// Downloads one shared deck file. The returned cards have `deckId == 0`:
  /// shared files carry no local ids, and the caller assigns the real
  /// local deck id when inserting them into sqflite.
  Future<({TarotDeckModel deck, List<TarotCardModel> cards})> fetchSharedDeck(
    String path,
  ) async {
    final file = await _github.getRepoFile(_token(), path);
    final raw = file['content'] as String?;
    if (raw == null || raw.trim().isEmpty) {
      throw GithubException('Shared deck file is empty: $path');
    }

    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(GithubService.decodeBase64Content(raw));
      if (decoded is! Map<String, dynamic>) {
        throw GithubException('Shared deck file has the wrong shape: $path');
      }
      data = decoded;
    } on GithubException {
      rethrow;
    } catch (_) {
      throw GithubException('Shared deck file is not valid JSON: $path');
    }

    final deckRaw = data['deck'];
    final cardsRaw = data['cards'];
    if (deckRaw is! Map || cardsRaw is! List) {
      throw GithubException('Shared deck file has the wrong shape: $path');
    }

    TarotDeckModel deck;
    try {
      deck = TarotDeckModel.fromMap(Map<String, dynamic>.from(deckRaw));
    } catch (_) {
      throw GithubException('Shared deck file has an invalid deck: $path');
    }

    final cards = <TarotCardModel>[];
    for (final rawCard in cardsRaw) {
      if (rawCard is! Map) {
        throw GithubException('Shared deck file has an invalid card: $path');
      }
      final cardMap = Map<String, dynamic>.from(rawCard);
      // Shared files must not carry local ids; the caller re-assigns
      // deck_id on insert, so it is 0 here by definition.
      cardMap.remove('id');
      cardMap['deck_id'] = 0;
      try {
        cards.add(TarotCardModel.fromMap(cardMap));
      } catch (_) {
        throw GithubException('Shared deck file has an invalid card: $path');
      }
    }

    return (deck: deck, cards: cards);
  }

  /// Deck files currently waiting in `server/submissions/`.
  Future<List<SharedDeckInfo>> listSubmissions() async {
    final entries = await _github.listRepoContents(_token(), submissionsDir);
    return _jsonFiles(entries, submissionsDir);
  }

  /// Submits [deck] + [cards] for review: creates a `submit/...` branch,
  /// writes `server/submissions/<slug>.json` on it, and opens a pull
  /// request against `main`. Returns the pull request URL.
  /// Shared files must not carry local ids, so `id` is stripped from the
  /// deck map and from every card map before encoding.
  Future<String> submitDeck(
    TarotDeckModel deck,
    List<TarotCardModel> cards,
  ) async {
    final token = _token();
    final login = _login();
    final slug = _slugify(deck.name);
    final branch =
        'submit/$login-$slug-${DateTime.now().millisecondsSinceEpoch}';

    final mainSha = await _github.getBranchSha(token, baseBranch);
    await _github.createBranch(token, branch: branch, sha: mainSha);

    final deckMap = deck.toMap()..remove('id');
    final cardMaps = cards
        .map((card) => card.toMap()..remove('id'))
        .toList();
    final json = jsonEncode(<String, dynamic>{
      'deck': deckMap,
      'cards': cardMaps,
    });
    final contentBase64 = base64Encode(utf8.encode(json));

    await _github.createOrUpdateFile(
      token,
      path: '$submissionsDir/$slug.json',
      contentBase64: contentBase64,
      message: 'Gửi bộ bài: ${deck.name}',
      branch: branch,
    );

    final pr = await _github.createPullRequest(
      token,
      title: 'Gửi bộ bài: ${deck.name}',
      body: 'Tác giả: $login\n\n'
          'Bộ bài "${deck.name}" (${cards.length} lá) gửi lên server chờ duyệt.',
      head: branch,
      base: baseBranch,
    );
    final url = pr['html_url'] as String?;
    if (url == null || url.isEmpty) {
      throw GithubException('Could not read the pull request URL');
    }
    return url;
  }

  /// Open submission pull requests (head branch starts with `submit/`).
  Future<List<OpenSubmission>> listOpenSubmissions() async {
    final prs = await _github.listOpenPullRequests(_token());
    final result = <OpenSubmission>[];
    for (final pr in prs) {
      final head = pr['head'];
      final branch = head is Map ? head['ref'] as String? : null;
      if (branch == null || !branch.startsWith('submit/')) continue;
      final user = pr['user'];
      final author = user is Map ? user['login'] as String? : null;
      final number = pr['number'];
      final title = pr['title'] as String?;
      final url = pr['html_url'] as String?;
      if (number is! int || title == null || url == null) continue;
      result.add(OpenSubmission(
        number: number,
        title: title,
        author: author ?? '',
        url: url,
        branch: branch,
      ));
    }
    return result;
  }

  /// Admin: approves a submission by merging its pull request.
  /// (Moving the file into `server/decks/` is a separate step:
  /// [moveSubmissionToShared], run after the merge.)
  Future<void> approveSubmission(int number) async {
    await _github.mergePullRequest(_token(), number);
  }

  /// Admin: rejects a submission by closing its pull request.
  Future<void> rejectSubmission(int number) async {
    await _github.closePullRequest(_token(), number);
  }

  /// Admin: moves an approved submission file into the shared library on
  /// `main`, then deletes it from `server/submissions/`.
  Future<void> moveSubmissionToShared(String submissionPath) async {
    final token = _token();
    final file = await _github.getRepoFile(token, submissionPath);
    final raw = file['content'] as String?;
    final sha = file['sha'] as String?;
    if (raw == null || raw.trim().isEmpty) {
      throw GithubException('Submission file is empty: $submissionPath');
    }
    if (sha == null || sha.isEmpty) {
      throw GithubException('Submission file has no sha: $submissionPath');
    }
    final filename = submissionPath.split('/').last;
    // Normalize the base64: decode to UTF-8, then re-encode without
    // whitespace, so the shared copy is byte-clean.
    final normalized =
        base64Encode(utf8.encode(GithubService.decodeBase64Content(raw)));
    await _github.createOrUpdateFile(
      token,
      path: '$sharedDir/$filename',
      contentBase64: normalized,
      message: 'Duyệt bộ bài: $filename',
      branch: baseBranch,
    );
    await _github.deleteFile(
      token,
      path: submissionPath,
      message: 'Chuyển vào kho chung: $filename',
      sha: sha,
      branch: baseBranch,
    );
  }

  /// Admin: deletes a shared deck from `server/decks/` on `main`.
  Future<void> deleteSharedDeck(String path) async {
    final token = _token();
    final file = await _github.getRepoFile(token, path);
    final sha = file['sha'] as String?;
    if (sha == null || sha.isEmpty) {
      throw GithubException('Shared deck file has no sha: $path');
    }
    await _github.deleteFile(
      token,
      path: path,
      message: 'Xóa bộ bài: ${path.split('/').last}',
      sha: sha,
      branch: baseBranch,
    );
  }

  List<SharedDeckInfo> _jsonFiles(
    List<Map<String, dynamic>> entries,
    String dir,
  ) {
    final result = <SharedDeckInfo>[];
    for (final entry in entries) {
      if (entry['type'] != 'file') continue;
      final name = entry['name'] as String?;
      if (name == null || !name.endsWith('.json')) continue;
      final path = entry['path'] as String? ?? '$dir/$name';
      result.add(SharedDeckInfo(
        name: name.substring(0, name.length - '.json'.length),
        path: path,
      ));
    }
    return result;
  }

  /// Lowercases the deck name, turns spaces/underscores into `-`, drops
  /// anything that is not [a-z0-9-], collapses repeated `-` and trims
  /// leading/trailing `-`. Falls back to `bo-bai` when nothing survives
  /// (e.g. a name made only of diacritics).
  String _slugify(String name) {
    var slug = name.toLowerCase().replaceAll(RegExp(r'[ _]+'), '-');
    slug = slug.replaceAll(RegExp(r'[^a-z0-9-]'), '');
    slug = slug.replaceAll(RegExp(r'-{2,}'), '-');
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'bo-bai' : slug;
  }
}
