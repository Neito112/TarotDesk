import 'dart:convert';

import 'github_service.dart';
import '../../logic/auth_provider.dart';
import 'database_helper.dart';
import '../models/tarot_card.dart';
import '../models/tarot_deck.dart';
import '../models/tarot_reading.dart';

/// What [GistSyncService.syncOnLogin] did.
///
/// - [downloaded]: the cloud gist had data, this device had none, so the
///   gist was imported into the local database.
/// - [uploaded]: this device had user data, the gist was empty or missing,
///   so local data was pushed to the gist.
/// - [upToDate]: both sides already have data; nothing was overwritten.
///   The user syncs explicitly from the sync button in that case.
/// - [noData]: neither side has user data, so there was nothing to do.
enum GistSyncOutcome { downloaded, uploaded, upToDate, noData }

/// Syncs the user's decks, cards and readings with one private GitHub gist
/// owned by the logged-in account.
///
/// The local sqflite database stays the working store; the gist is only a
/// cloud copy. Sync NEVER deletes local data: downloads only add decks,
/// cards and readings that are not already present (matched by name and
/// date), and a failed network/API call throws a [GithubException] for the
/// caller to handle (the login screen ignores it silently).
class GistSyncService {
  final AuthProvider auth;

  /// Instance of the GitHub API client (zero-arg constructor per contract).
  final GithubService _github = GithubService();

  GistSyncService(this.auth);

  /// The single file inside the sync gist.
  static const String _fileName = 'tarotdesk-data.json';

  /// Name of the seeded deck that ships with a fresh install. It is a data
  /// identifier, not UI text.
  static const String _baseDeckName = 'Bộ bài cơ bản';

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

  String _descriptionFor(String login) => 'TarotDesk — dữ liệu của $login';

  String _emptyPayload() => jsonEncode(<String, dynamic>{
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'decks': <dynamic>[],
        'cards': <dynamic>[],
        'readings': <dynamic>[],
      });

  /// The `content` of the sync file inside [gist], or null when the gist or
  /// the file is missing.
  String? _gistFileContent(Map<String, dynamic>? gist) {
    if (gist == null) return null;
    final files = gist['files'];
    if (files is! Map) return null;
    final file = files[_fileName];
    if (file is! Map) return null;
    final content = file['content'];
    return content is String ? content : null;
  }

  /// Content of the sync file in the user's gist, or null when there is
  /// no gist, no sync file, or the file is empty. The gist LIST endpoint
  /// does not return file contents, so this fetches the full gist with
  /// [GithubService.getGist] first.
  Future<String?> _syncFileContent() async {
    final gist = await findGist();
    if (gist == null) return null;
    final gistId = gist['id'] as String?;
    if (gistId == null || gistId.isEmpty) return null;
    final full = await _github.getGist(_token(), gistId);
    return _gistFileContent(full);
  }

  /// Finds the user's sync gist (matched by its exact description), or null
  /// when the user has no sync gist yet.
  Future<Map<String, dynamic>?> findGist() async {
    final token = _token();
    final expected = _descriptionFor(_login());
    final gists = await _github.listGists(token);
    for (final gist in gists) {
      if (gist['description'] == expected) return gist;
    }
    return null;
  }

  /// Returns the user's sync gist, creating a private one with an empty
  /// payload when it does not exist yet.
  Future<Map<String, dynamic>> findOrCreateGist() async {
    final existing = await findGist();
    if (existing != null) return existing;
    return await _github.createGist(
      _token(),
      description: _descriptionFor(_login()),
      files: <String, String>{_fileName: _emptyPayload()},
      isPublic: false,
    );
  }

  /// Pushes all local decks, cards and readings to the sync gist.
  /// The JSON carries the LOCAL ids (deck_id / card_ids refer to local
  /// sqflite ids); the downloading device remaps them by name.
  Future<void> uploadFromLocal() async {
    final token = _token();
    final db = DatabaseHelper.instance;

    final decks = await db.getDecks();
    final cards = <Map<String, dynamic>>[];
    for (final deck in decks) {
      final deckId = deck.id;
      if (deckId == null) continue;
      final deckCards = await db.getCardsByDeckId(deckId);
      cards.addAll(deckCards.map((card) => card.toMap()));
    }
    final readings = await db.getReadings();

    final payload = jsonEncode(<String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'decks': decks.map((deck) => deck.toMap()).toList(),
      'cards': cards,
      'readings': readings.map((reading) => reading.toMap()).toList(),
    });

    final gist = await findOrCreateGist();
    final gistId = gist['id'] as String?;
    if (gistId == null || gistId.isEmpty) {
      throw GithubException('Could not find or create the sync gist');
    }
    await _github.patchGist(
      token,
      gistId,
      files: <String, String>{_fileName: payload},
    );
  }

  /// Imports the sync gist into the local database. Does nothing when there
  /// is no gist or no sync file. NEVER deletes local data.
  ///
  /// ID REMAPPING (critical): the ids in the gist are the OTHER device's
  /// local sqflite ids and must never be reused as identity here. Decks are
  /// matched by (name, created_date), cards by (deck, name), readings by
  /// (name, date); everything new is inserted without an id so sqflite
  /// assigns fresh local ids, and reading card ids are resolved back to
  /// local card ids by card NAME.
  Future<void> downloadToLocal() async {
    final content = await _syncFileContent();
    if (content == null || content.trim().isEmpty) return;

    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw GithubException('Sync data is not a valid TarotDesk backup');
      }
      data = decoded;
    } on GithubException {
      rethrow;
    } catch (_) {
      throw GithubException('Sync data is not valid JSON');
    }

    final incomingDecks = _asMapList(data['decks'], 'decks');
    final incomingCards = _asMapList(data['cards'], 'cards');
    final incomingReadings = _asMapList(data['readings'], 'readings');

    final db = DatabaseHelper.instance;
    final localDecks = await db.getDecks();
    final localReadings = await db.getReadings();

    // Incoming card id -> card name / old deck id, for reading remapping.
    final incomingCardNameById = <int, String>{};
    final incomingCardDeckById = <int, int>{};
    // Incoming cards grouped by their (old) deck id.
    final cardsByOldDeck = <int, List<TarotCardModel>>{};
    for (final raw in incomingCards) {
      final card = _tryParseCard(raw);
      if (card == null || card.id == null) continue;
      incomingCardNameById[card.id!] = card.name;
      incomingCardDeckById[card.id!] = card.deckId;
      cardsByOldDeck.putIfAbsent(card.deckId, () => <TarotCardModel>[]).add(card);
    }

    // old deck id -> new local deck id.
    final deckIdMap = <int, int>{};

    for (final raw in incomingDecks) {
      final deck = _tryParseDeck(raw);
      if (deck == null || deck.id == null) continue;
      final oldId = deck.id!;

      // Dedup: a local deck with the same name AND created_date.
      TarotDeckModel? existing;
      for (final local in localDecks) {
        if (local.name == deck.name &&
            local.createdDate.toIso8601String() ==
                deck.createdDate.toIso8601String()) {
          existing = local;
          break;
        }
      }
      // Guard: the seeded base deck is never imported twice. The
      // name + created_date dedup above already covers it, but the rule
      // is named explicitly: any local deck with that name wins,
      // whatever its created_date.
      if (existing == null && deck.name == _baseDeckName) {
        for (final local in localDecks) {
          if (local.name == _baseDeckName) {
            existing = local;
            break;
          }
        }
      }

      final incomingDeckCards = cardsByOldDeck[oldId] ?? const <TarotCardModel>[];

      if (existing != null && existing.id != null) {
        final localId = existing.id!;
        deckIdMap[oldId] = localId;
        // Deck already exists: insert only the cards missing from it
        // (matched by card name), without an id.
        final localCards = await db.getCardsByDeckId(localId);
        final localNames = localCards.map((card) => card.name).toSet();
        for (final card in incomingDeckCards) {
          if (localNames.contains(card.name)) continue;
          await db.insertCard(TarotCardModel(
            deckId: localId,
            name: card.name,
            meaning: card.meaning,
            imagePath: card.imagePath,
          ));
          localNames.add(card.name);
        }
      } else {
        // Brand-new deck: insert deck + its cards in one transaction.
        // Cards are rebuilt without an id (so sqflite assigns fresh
        // local ids) and deduplicated by name within the deck.
        final newCards = <TarotCardModel>[];
        final seenNames = <String>{};
        for (final card in incomingDeckCards) {
          if (!seenNames.add(card.name)) continue;
          newCards.add(TarotCardModel(
            // insertFullDeckWithCards overwrites deck_id with the new id.
            deckId: 0,
            name: card.name,
            meaning: card.meaning,
            imagePath: card.imagePath,
          ));
        }
        final newId = await db.insertFullDeckWithCards(
          TarotDeckModel(name: deck.name, createdDate: deck.createdDate),
          newCards,
        );
        deckIdMap[oldId] = newId;
        localDecks.add(
          TarotDeckModel(id: newId, name: deck.name, createdDate: deck.createdDate),
        );
      }
    }

    // Re-read local cards per deck (now including everything just
    // imported) so reading card ids can be resolved by card name.
    final localCardIdByDeckAndName = <int, Map<String, int>>{};
    for (final newDeckId in deckIdMap.values.toSet()) {
      final cards = await db.getCardsByDeckId(newDeckId);
      final byName = <String, int>{};
      for (final card in cards) {
        if (card.id != null) byName[card.name] = card.id!;
      }
      localCardIdByDeckAndName[newDeckId] = byName;
    }

    // Readings already present locally, keyed by (name, date).
    final existingReadingKeys = <String>{
      for (final reading in localReadings)
        '${reading.name}|||${reading.date.toIso8601String()}',
    };

    for (final raw in incomingReadings) {
      final reading = _tryParseReading(raw);
      if (reading == null) continue;
      // Remap the deck: skip readings whose deck is unknown here.
      final newDeckId = deckIdMap[reading.deckId];
      if (newDeckId == null) continue;

      // Remap each card id by card NAME (incoming ids are the other
      // device's local ids). Unresolvable cards are dropped, keeping
      // is_reversed_list aligned with the surviving card ids.
      final newCardIds = <int>[];
      final newReversed = <bool>[];
      for (var i = 0; i < reading.cardIds.length; i++) {
        final oldCardId = reading.cardIds[i];
        final reversed = i < reading.isReversedList.length
            ? reading.isReversedList[i]
            : false;
        final cardName = incomingCardNameById[oldCardId];
        if (cardName == null) continue;
        final newCardId = localCardIdByDeckAndName[newDeckId]?[cardName];
        if (newCardId == null) continue;
        newCardIds.add(newCardId);
        newReversed.add(reversed);
      }

      // Dedup: a local reading with the same name AND date.
      final key = '${reading.name}|||${reading.date.toIso8601String()}';
      if (existingReadingKeys.contains(key)) continue;

      await db.insertReading(TarotReadingModel(
        deckId: newDeckId,
        name: reading.name,
        date: reading.date,
        cardIds: newCardIds,
        isReversedList: newReversed,
      ));
      existingReadingKeys.add(key);
    }
  }

  /// The login policy. Throws [GithubException] on any network/API failure;
  /// the caller (login screen) catches and ignores it silently.
  Future<GistSyncOutcome> syncOnLogin() async {
    final decks = await DatabaseHelper.instance.getDecks();
    final readings = await DatabaseHelper.instance.getReadings();
    final hasUserData = decks.any((deck) => deck.name != _baseDeckName) ||
        readings.isNotEmpty;

    // The gist LIST response has no file contents; fetch the full gist
    // to see whether the sync file actually holds data.
    final content = await _syncFileContent();
    if (content == null || content.trim().isEmpty) {
      if (hasUserData) {
        await uploadFromLocal();
        return GistSyncOutcome.uploaded;
      }
      return GistSyncOutcome.noData;
    }

    if (!hasUserData) {
      await downloadToLocal();
      return GistSyncOutcome.downloaded;
    }

    // Both sides have data: never auto-overwrite in either direction.
    // The user syncs explicitly from the sync button.
    return GistSyncOutcome.upToDate;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value, String field) {
    if (value == null) return const <Map<String, dynamic>>[];
    if (value is! List) {
      throw GithubException('Sync data field "$field" is not a list');
    }
    final result = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        result.add(item);
      } else if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      } else {
        throw GithubException('Sync data field "$field" has an invalid entry');
      }
    }
    return result;
  }

  TarotDeckModel? _tryParseDeck(Map<String, dynamic> map) {
    try {
      return TarotDeckModel.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  TarotCardModel? _tryParseCard(Map<String, dynamic> map) {
    try {
      return TarotCardModel.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  TarotReadingModel? _tryParseReading(Map<String, dynamic> map) {
    try {
      return TarotReadingModel.fromMap(map);
    } catch (_) {
      return null;
    }
  }
}
