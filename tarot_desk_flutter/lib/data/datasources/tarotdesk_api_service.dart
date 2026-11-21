import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Exception thrown by [TarotdeskApiService] for every failure mode.
///
/// [code] is a short machine-readable code:
/// * `'network'` — no connectivity / socket error / timeout.
/// * `'unauthorized'` — HTTP 401 (bad, expired or revoked session).
/// * `'forbidden'` — HTTP 403 (logged in, but not allowed).
/// * `'server'` — anything else (other HTTP status, bad JSON, ...).
///
/// [toString] returns only [message], so the exception is safe to show
/// in UI. It never contains a token.
class TarotdeskApiException implements Exception {
  const TarotdeskApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// The authenticated Google user, as returned by the Worker (`GET /me`).
///
/// [isAdmin] comes from the Worker's `is_admin` flag on the `/me`
/// response (top level, or inside the `user` object); it defaults to
/// `false`. The app decides admin-ness from the email instead
/// ([AuthProvider.isAdmin]); this flag is the Worker's view of it.
class TarotdeskUser {
  const TarotdeskUser({
    required this.sub,
    required this.email,
    required this.name,
    required this.picture,
    this.isAdmin = false,
  });

  factory TarotdeskUser.fromJson(
    Map<String, dynamic> json, {
    bool? isAdmin,
  }) {
    return TarotdeskUser(
      sub: (json['sub'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      picture: (json['picture'] as String?) ?? '',
      isAdmin: isAdmin ??
          (json['is_admin'] as bool?) ??
          false,
    );
  }

  /// Google account id (`sub` claim).
  final String sub;

  /// Google account email — the admin check keys off this.
  final String email;

  /// Display name from the Google profile.
  final String name;

  /// Profile picture URL from the Google profile (may be empty).
  final String picture;

  /// True when the Worker reports this user is the server admin.
  final bool isAdmin;
}

/// The ONLY backend client of the app.
///
/// Every call goes to the TarotDesk Cloudflare Worker — the app never
/// calls Google or GitHub APIs directly. The Worker owns the Google
/// OAuth exchange (the client secret lives there as a Worker secret),
/// verifies the Google identity, and stores per-user data.
///
/// The service stores NO token: every authenticated method takes the
/// Worker `session_token` as a parameter, and the token is never
/// logged or printed. Authenticated calls send
/// `Authorization: Bearer <session_token>`.
///
/// Every method either returns a result or throws
/// [TarotdeskApiException] — the app must never crash on a
/// network/API failure.
class TarotdeskApiService {
  TarotdeskApiService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Base URL of the TarotDesk Cloudflare Worker (the only backend).
  static const String baseUrl =
      'https://tarotdesk-oauth.thewolverineking.workers.dev';

  static const Duration _requestTimeout = Duration(seconds: 20);

  /// Release the underlying HTTP client. Only call this when the
  /// service owns the client (i.e. no client was injected).
  void close() => _client.close();

  Map<String, String> _authHeaders(String sessionToken) {
    return <String, String>{
      'Authorization': 'Bearer $sessionToken',
      'Accept': 'application/json',
    };
  }

  Map<String, String> _jsonHeaders([String? sessionToken]) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (sessionToken != null && sessionToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $sessionToken';
    }
    return headers;
  }

  // ------------------------------------------------------------------
  // Low-level helpers
  // ------------------------------------------------------------------

  /// Run an HTTP call, mapping connectivity failures to a
  /// `code: 'network'` [TarotdeskApiException].
  ///
  /// NOTE: no `dart:io` import here — this app builds for Flutter web,
  /// where `dart:io` does not exist. Transport failures arrive as
  /// [http.ClientException] on every platform (package:http wraps the
  /// underlying socket errors), so that is what we catch.
  Future<http.Response> _send(
    Future<http.Response> Function() call,
  ) async {
    try {
      return await call().timeout(_requestTimeout);
    } on TimeoutException {
      throw const TarotdeskApiException(
        'network',
        'Timed out waiting for the server. Please try again.',
      );
    } on http.ClientException {
      throw const TarotdeskApiException(
        'network',
        'Could not reach the server. Please check your connection and try again.',
      );
    }
  }

  /// Decode a successful response body as JSON. An empty body yields
  /// an empty map; a non-JSON body yields an empty map as well, so
  /// callers always see [TarotdeskApiException] instead of a crash.
  dynamic _decodeSuccess(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Throw a [TarotdeskApiException] for a non-2xx response, mapping
  /// the status to its code and using the server's JSON `message` /
  /// `error` field when present.
  Never _throwApiError(http.Response response) {
    String message = 'Server error (${response.statusCode}).';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final serverMessage = decoded['message'] ?? decoded['error'];
        if (serverMessage is String && serverMessage.isNotEmpty) {
          message = serverMessage;
        }
      }
    } catch (_) {
      // Keep the fallback message.
    }
    switch (response.statusCode) {
      case 401:
        throw TarotdeskApiException('unauthorized', message);
      case 403:
        throw TarotdeskApiException('forbidden', message);
      default:
        throw TarotdeskApiException('server', message);
    }
  }

  /// Perform one Worker request and return the decoded JSON body.
  /// Throws [TarotdeskApiException] on any failure.
  Future<dynamic> _call(
    String method,
    String path, {
    String? sessionToken,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = _jsonHeaders(sessionToken);
    late final http.Response response;
    switch (method) {
      case 'GET':
        response = await _send(() => _client.get(uri, headers: headers));
      case 'POST':
        response = await _send(
          () => _client.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          ),
        );
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return _decodeSuccess(response);
  }

  List<Map<String, dynamic>> _asMapList(dynamic decoded, [String? listKey]) {
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    if (decoded is Map<String, dynamic> && listKey != null) {
      final nested = decoded[listKey];
      if (nested is List) {
        return nested
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
      }
    }
    if (decoded is Map) {
      return decoded.values
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _asMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  // ------------------------------------------------------------------
  // Google login (Web Application Flow)
  // ------------------------------------------------------------------

  /// Exchange a Google authorization `code` for a Worker session.
  ///
  /// `POST /google-token` with `{code, redirect_uri}`. Returns the
  /// decoded JSON `{session_token, user: {...}}`.
  Future<Map<String, dynamic>> exchangeGoogleCode({
    required String code,
    required String redirectUri,
  }) async {
    final decoded = await _call(
      'POST',
      '/google-token',
      body: <String, dynamic>{
        'code': code,
        'redirect_uri': redirectUri,
      },
    );
    return _asMap(decoded);
  }

  /// `GET /me` — the user behind [sessionToken], plus the Worker's
  /// `is_admin` flag.
  Future<TarotdeskUser> getMe(String sessionToken) async {
    final decoded = await _call('GET', '/me', sessionToken: sessionToken);
    final map = _asMap(decoded);
    final userJson = map['user'];
    final userMap = userJson is Map<String, dynamic>
        ? userJson
        : userJson is Map
            ? Map<String, dynamic>.from(userJson)
            : map;
    final isAdmin = (map['is_admin'] as bool?) ??
        (userMap['is_admin'] as bool?) ??
        false;
    return TarotdeskUser.fromJson(userMap, isAdmin: isAdmin);
  }

  // ------------------------------------------------------------------
  // Per-user data
  // ------------------------------------------------------------------

  /// `GET /data` — the stored JSON object for this user, or `{}` when
  /// there is none / it is empty.
  ///
  /// The object has the shape `{version, decks, cards, readings, ...}`
  /// (same fields the old local sync payload carried).
  Future<Map<String, dynamic>> getData(String sessionToken) async {
    final decoded = await _call('GET', '/data', sessionToken: sessionToken);
    return _asMap(decoded);
  }

  /// `POST /data` — replace the stored JSON object for this user.
  /// [data] is sent as the request body as-is.
  Future<void> saveData(
    String sessionToken,
    Map<String, dynamic> data,
  ) async {
    await _call('POST', '/data', sessionToken: sessionToken, body: data);
  }

  // ------------------------------------------------------------------
  // Shared decks
  // ------------------------------------------------------------------

  /// `GET /shared-decks` — decks in the shared library, visible to
  /// everyone. The `Authorization` header is only sent when a
  /// [sessionToken] is given (guests can browse without logging in).
  ///
  /// Each entry is `{"id", "name", "deck": {...}, "cards": [...]}`.
  Future<List<Map<String, dynamic>>> listSharedDecks(
    String? sessionToken,
  ) async {
    final decoded = await _call(
      'GET',
      '/shared-decks',
      sessionToken: sessionToken,
    );
    return _asMapList(decoded, 'decks');
  }

  /// `POST /submit-deck` — submit a deck for admin review.
  ///
  /// [deckJson] is `{"deck": {...}, "cards": [...]}` (the shared-deck
  /// JSON shape); it is sent as the request body. Returns the
  /// submission id. The Worker assigns the deck its permanent
  /// `deck_key` at submit time (the submission id itself) and
  /// stores its translations permanently under it — see
  /// [submitDeckDetailed] when the caller also needs the key.
  Future<String> submitDeck(
    String sessionToken,
    Map<String, dynamic> deckJson,
  ) async {
    final detailed = await submitDeckDetailed(sessionToken, deckJson);
    final id = detailed['id'];
    if (id is String && id.isNotEmpty) return id;
    throw const TarotdeskApiException(
      'server',
      'The server did not return a submission id.',
    );
  }

  /// `POST /submit-deck`, returning the full response
  /// `{'id': ..., 'deck_key': ...}`. The `deck_key` is the deck's
  /// permanent identity from here on: it is carried unchanged
  /// through approval into the shared library, and the deck's
  /// stored translations are keyed by it.
  Future<Map<String, dynamic>> submitDeckDetailed(
    String sessionToken,
    Map<String, dynamic> deckJson,
  ) async {
    final body = deckJson.containsKey('deck') && deckJson.containsKey('cards')
        ? deckJson
        : <String, dynamic>{
            'deck': deckJson,
            'cards': deckJson['cards'] ?? <dynamic>[],
          };
    final decoded = await _call(
      'POST',
      '/submit-deck',
      sessionToken: sessionToken,
      body: body,
    );
    final map = _asMap(decoded);
    final id = map['id'] ?? map['submission_id'];
    if (id is String && id.isNotEmpty) return map;
    final submission = map['submission'];
    if (submission is Map && submission['id'] is String) {
      return <String, dynamic>{
        'id': submission['id'],
        'deck_key': submission['deck_key'] ?? submission['id'],
      };
    }
    throw const TarotdeskApiException(
      'server',
      'The server did not return a submission id.',
    );
  }

  // ------------------------------------------------------------------
  // Admin
  // ------------------------------------------------------------------

  /// `GET /admin/submissions` — decks waiting for review (admin only).
  Future<List<Map<String, dynamic>>> listSubmissions(
    String sessionToken,
  ) async {
    final decoded = await _call(
      'GET',
      '/admin/submissions',
      sessionToken: sessionToken,
    );
    return _asMapList(decoded, 'submissions');
  }

  /// `POST /admin/approve` with `{id}` — approve a submission
  /// (admin only). The deck moves into the shared library. This is
  /// a PURE MOVE: the deck's translations were already stored
  /// permanently at submit time under its deck_key, so approval
  /// re-translates nothing and touches no translation rows.
  Future<void> approveSubmission(String sessionToken, String id) async {
    await _call(
      'POST',
      '/admin/approve',
      sessionToken: sessionToken,
      body: <String, dynamic>{'id': id},
    );
  }

  /// `POST /admin/reject` with `{id}` — reject a submission
  /// (admin only).
  Future<void> rejectSubmission(String sessionToken, String id) async {
    await _call(
      'POST',
      '/admin/reject',
      sessionToken: sessionToken,
      body: <String, dynamic>{'id': id},
    );
  }

  /// `POST /admin/delete-shared-deck` with `{id}` — delete a deck
  /// from the shared library (admin only).
  Future<void> deleteSharedDeck(String sessionToken, String id) async {
    await _call(
      'POST',
      '/admin/delete-shared-deck',
      sessionToken: sessionToken,
      body: <String, dynamic>{'id': id},
    );
  }

  /// `GET /admin/shared-decks` — the shared library as the admin
  /// sees it (admin only). Same entry shape as [listSharedDecks].
  Future<List<Map<String, dynamic>>> listSharedDecksAdmin(
    String sessionToken,
  ) async {
    final decoded = await _call(
      'GET',
      '/admin/shared-decks',
      sessionToken: sessionToken,
    );
    return _asMapList(decoded, 'decks');
  }

  // ------------------------------------------------------------------
  // Content translation (POST /translate) — see
  // lib/core/translation_service.dart and i18n/worker/.
  //
  // The app never calls a translation vendor directly and holds
  // no translation API key: the Worker owns the engines
  // (Workers AI m2m100 first, Google Cloud Translation as an
  // optional fallback behind a Worker secret) and the shared D1
  // translation cache. [sessionToken] is optional — guests are
  // served under the Worker's anonymous cap; pass null for them.
  // Throws [TarotdeskApiException] like every other call here;
  // TranslationService catches it and shows the original text.
  //
  // NOTE: this endpoint is for AD-HOC text only. A deck's
  // translations live permanently in the Worker's
  // `deck_translations` table instead — see
  // [storeDeckTranslations] / [fetchDeckTranslations] above.
  // ------------------------------------------------------------------

  /// `POST /translate` with
  /// `{texts: [...], target_lang, source_lang?}`.
  ///
  /// Returns one [WorkerTranslation] per input text, in order.
  /// A result with `translated == false` carries the original
  /// text — the caller displays it as-is (see
  /// [TranslationService]).
  Future<List<WorkerTranslation>> translateTexts({
    String? sessionToken,
    required List<String> texts,
    required String targetLang,
    String? sourceLang,
  }) async {
    if (texts.isEmpty) return const <WorkerTranslation>[];
    final decoded = await _call(
      'POST',
      '/translate',
      sessionToken: sessionToken,
      body: <String, dynamic>{
        'texts': texts,
        'target_lang': targetLang,
        if (sourceLang != null && sourceLang.isNotEmpty)
          'source_lang': sourceLang,
      },
    );
    final map = _asMap(decoded);
    final list = _asMapList(map['translations'], 'translations');
    if (list.length != texts.length) {
      throw const TarotdeskApiException(
        'server',
        'The translation service returned the wrong number of results.',
      );
    }
    return <WorkerTranslation>[
      for (var i = 0; i < texts.length; i++)
        WorkerTranslation.fromJson(list[i], fallbackText: texts[i]),
    ];
  }

  // ------------------------------------------------------------------
  // Permanent deck translations (POST /deck/pretranslate +
  // GET /deck-translations) — see
  // lib/core/translation_service.dart (storeDeckTranslations).
  //
  // A deck's translations are PERMANENT per-deck / per-user data in
  // the Worker's `deck_translations` table — keyed by
  // (deck_key, card_id, lang), owned by 'shared' or by the author's
  // email — NOT entries in the `translations` content cache (that
  // table serves only the ad-hoc POST /translate below). Any
  // signed-in user can store their own decks: the Worker decides
  // the owner from the session, never from the client. The old V1
  // admin-only POST /admin/pretranslate endpoint is REMOVED.
  // The Worker queues the work in ctx.waitUntil() and returns
  // immediately, so these calls only ever wait for the quick 200
  // — the 20s timeout above is never the bottleneck.
  // Throws [TarotdeskApiException] like every other call here.
  // ------------------------------------------------------------------

  /// `POST /deck/pretranslate` with
  /// `{deck_key?, deck_id?, deck_name?, cards:
  /// [{card_id?, name, meaning}], source_lang?}`.
  ///
  /// Translates the given cards into all four UI languages
  /// (en / zh / ko / ja) in the background and stores them
  /// PERMANENTLY under [deckKey] (or the key derived from the
  /// caller's session + [deckId]). `card_id` is the card's 0-based
  /// position in the deck's card list — pass it explicitly for a
  /// single-card edit, omit it (array index) for a whole deck.
  /// [deckName] (when given) is stored as the deck-name row.
  /// Caps mirror the authed `/translate` limits: max 100 texts /
  /// 40,000 chars per call — callers chunk.
  Future<StoreDeckTranslationsResult> storeDeckTranslations({
    required String sessionToken,
    required String deckKey,
    String? deckName,
    required List<DeckTranslationItem> items,
    String? sourceLang,
  }) async {
    if (items.isEmpty &&
        (deckName == null || deckName.trim().isEmpty)) {
      return const StoreDeckTranslationsResult(
        deckKey: '',
        queuedCards: 0,
        languages: <String>[],
      );
    }
    final decoded = await _call(
      'POST',
      '/deck/pretranslate',
      sessionToken: sessionToken,
      body: <String, dynamic>{
        'deck_key': deckKey,
        if (deckName != null && deckName.trim().isNotEmpty)
          'deck_name': deckName,
        'cards': <Map<String, dynamic>>[
          for (final item in items)
            <String, dynamic>{
              'card_id': item.cardId,
              'name': item.name,
              'meaning': item.meaning,
            },
        ],
        if (sourceLang != null && sourceLang.isNotEmpty)
          'source_lang': sourceLang,
      },
    );
    final map = _asMap(decoded);
    final queued = map['queued_cards'];
    final langs = map['languages'];
    return StoreDeckTranslationsResult(
      deckKey: (map['deck_key'] as String?) ?? deckKey,
      queuedCards: queued is int ? queued : items.length,
      languages: langs is List
          ? langs.whereType<String>().toList(growable: false)
          : const <String>['en', 'zh', 'ko', 'ja'],
    );
  }

  /// `GET /deck-translations?deck_key=...&lang=...` (or
  /// `shared_id=...` for a shared deck) — the deck's PERMANENT
  /// stored translations for one language, as
  /// `{deck_key, lang, deck_name, cards: [{card_id, name,
  /// meaning}]}`. A fast D1 lookup: no MT call, no cache read.
  /// [sessionToken] is optional — shared decks and the base deck
  /// are public, so guests can read them without logging in;
  /// pass the token for personal decks (the Worker checks the
  /// caller owns them). Throws [TarotdeskApiException] on
  /// failure (unknown deck, not the owner, Worker down, ...).
  Future<StoredDeckTranslations> fetchDeckTranslations({
    String? sessionToken,
    String? deckKey,
    String? sharedId,
    required String lang,
  }) async {
    assert(
      (deckKey != null && deckKey.isNotEmpty) ||
          (sharedId != null && sharedId.isNotEmpty),
      'fetchDeckTranslations needs a deckKey or a sharedId',
    );
    final query = deckKey != null && deckKey.isNotEmpty
        ? 'deck_key=${Uri.encodeQueryComponent(deckKey)}'
        : 'shared_id=${Uri.encodeQueryComponent(sharedId!)}';
    final decoded = await _call(
      'GET',
      '/deck-translations?$query&lang=${Uri.encodeQueryComponent(lang)}',
      sessionToken: sessionToken,
    );
    final map = _asMap(decoded);
    final list = _asMapList(map['cards'], 'cards');
    return StoredDeckTranslations(
      deckKey: (map['deck_key'] as String?) ?? (deckKey ?? ''),
      lang: (map['lang'] as String?) ?? lang,
      deckName: (map['deck_name'] as String?) ?? '',
      cards: <StoredDeckTranslation>[
        for (final row in list)
          StoredDeckTranslation(
            cardId: (row['card_id'] as int?) ?? -1,
            name: (row['name'] as String?) ?? '',
            meaning: (row['meaning'] as String?) ?? '',
          ),
      ],
    );
  }
}

/// One card to store permanently: its 0-based position in the
/// deck's card list ([cardId]), its source name and its source
/// meaning. Positions are the identity — the same order the app
/// stores/reads the cards in, so rows map back to cards on any
/// device. The deck name travels separately (`deck_name`).
class DeckTranslationItem {
  const DeckTranslationItem({
    required this.cardId,
    required this.name,
    required this.meaning,
  });

  /// 0-based position in the deck's card list.
  final int cardId;

  /// Source-language card name.
  final String name;

  /// Source-language card meaning.
  final String meaning;
}

/// What `POST /deck/pretranslate` queued: the deck_key the rows
/// were stored under, the number of cards accepted, and the target
/// languages (always en / zh / ko / ja). The translations
/// themselves are not returned — they land in the Worker's
/// `deck_translations` table and are read back later through
/// `GET /deck-translations`.
class StoreDeckTranslationsResult {
  const StoreDeckTranslationsResult({
    required this.deckKey,
    required this.queuedCards,
    required this.languages,
  });

  /// deck_key the rows were stored under.
  final String deckKey;

  /// Cards accepted for background translation + permanent store.
  final int queuedCards;

  /// Target languages the Worker queued (en / zh / ko / ja).
  final List<String> languages;
}

/// One deck's permanent stored translations for one language, as
/// returned by `GET /deck-translations`.
class StoredDeckTranslations {
  const StoredDeckTranslations({
    required this.deckKey,
    required this.lang,
    required this.deckName,
    required this.cards,
  });

  /// deck_key the rows belong to.
  final String deckKey;

  /// Language of the stored rows ('en' / 'zh' / 'ko' / 'ja').
  final String lang;

  /// Translated deck name ('' when not stored yet).
  final String deckName;

  /// Translated cards, in card_id (position) order. The deck-name
  /// row (card_id -1) is NOT in here — it is [deckName].
  final List<StoredDeckTranslation> cards;
}

/// One stored card translation: the card's position in its deck
/// plus its translated name + meaning.
class StoredDeckTranslation {
  const StoredDeckTranslation({
    required this.cardId,
    required this.name,
    required this.meaning,
  });

  /// 0-based position in the deck's card list.
  final int cardId;

  /// Translated card name.
  final String name;

  /// Translated card meaning.
  final String meaning;
}

/// One string as translated by the Worker (`POST /translate`).
class WorkerTranslation {
  const WorkerTranslation({
    required this.text,
    required this.sourceLang,
    required this.translated,
    required this.engine,
    required this.fromCache,
  });

  factory WorkerTranslation.fromJson(
    Map<String, dynamic> json, {
    required String fallbackText,
  }) {
    final text = json['text'] as String?;
    return WorkerTranslation(
      text: (text == null || text.isEmpty) ? fallbackText : text,
      sourceLang: (json['source_lang'] as String?) ?? '',
      translated: (json['translated'] as bool?) ?? false,
      engine: (json['engine'] as String?) ?? 'none',
      fromCache: (json['cached'] as bool?) ?? false,
    );
  }

  /// Translated text, or the original when `translated` is false.
  final String text;

  /// Source language the Worker detected or was given ('' if unknown).
  final String sourceLang;

  /// False when [text] is the untranslated original.
  final bool translated;

  /// `'workers-ai'`, `'google'`, `'cache'` or `'none'`.
  final String engine;

  /// True when served from the Worker's D1 translation cache.
  final bool fromCache;
}

