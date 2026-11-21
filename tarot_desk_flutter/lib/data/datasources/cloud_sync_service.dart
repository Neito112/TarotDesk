import 'dart:async';

import 'tarotdesk_api_service.dart';
import '../../core/translation_service.dart';
import '../../logic/auth_provider.dart';
import 'database_helper.dart';
import '../models/tarot_card.dart';
import '../models/tarot_deck.dart';
import '../models/tarot_reading.dart';

/// What [CloudSyncService.syncAfterLogin] did.
///
/// - [downloaded]: the cloud store had data, this device had none, so the
///   cloud data was imported into the local database.
/// - [uploaded]: this device had user data, the cloud store was empty or
///   missing, so local data was pushed to the cloud.
/// - [upToDate]: both sides already have data; nothing was overwritten.
///   The automatic login/reload sync never overwrites when both sides
///   have data (there is no manual sync button any more).
/// - [noData]: neither side has user data, so there was nothing to do.
enum CloudSyncOutcome { downloaded, uploaded, upToDate, noData }

/// Syncs the user's decks, cards and readings with the TarotDesk cloud
/// store (the Worker backend, one record per Google account).
///
/// The local sqflite database stays the working store; the cloud is only
/// a copy. Sync NEVER deletes local data: downloads only add decks,
/// cards and readings that are not already present (matched by name and
/// date), and a failed network/API call throws a [TarotdeskApiException]
/// for the caller to handle (the login screen ignores it silently).
class CloudSyncService {
  final AuthProvider auth;

  /// Instance of the Worker API client (zero-arg constructor per contract).
  final TarotdeskApiService _api = TarotdeskApiService();

  /// Resolves the active system language code ('vi' / 'en' / 'zh' /
  /// 'ko' / 'ja') — normally `() => settings.language.code`,
  /// wired by the caller (see `main.dart` providers). When unset
  /// the normaliser assumes Vietnamese, which makes warming a
  /// no-op for the seeded base deck and harmless otherwise.
  final String Function()? targetLanguageCode;

  /// Lazily built normaliser: shares this service's API client
  /// and reads the session token fresh from [auth] on every
  /// call, so it never stores a token.
  TranslationService? _translator;
  TranslationService get _translationService => _translator ??=
      TranslationService(
        _api,
        sessionToken: () => auth.sessionToken,
        targetLanguageCode: () => targetLanguageCode?.call() ?? 'vi',
        userSub: () => auth.user?.sub,
      );

  CloudSyncService(this.auth, {this.targetLanguageCode});

  /// Name of the seeded deck that ships with a fresh install. It is a data
  /// identifier, not UI text.
  static const String _baseDeckName = 'Bộ bài cơ bản';

  String _sessionToken() {
    final token = auth.sessionToken;
    if (token == null || token.isEmpty) {
      throw TarotdeskApiException('unauthorized', 'Not logged in');
    }
    return token;
  }

  /// True when the stored cloud data holds no decks, cards or readings.
  bool _isEmptyData(Map<String, dynamic> data) {
    final decks = data['decks'];
    final cards = data['cards'];
    final readings = data['readings'];
    final decksEmpty = decks is! List || decks.isEmpty;
    final cardsEmpty = cards is! List || cards.isEmpty;
    final readingsEmpty = readings is! List || readings.isEmpty;
    return decksEmpty && cardsEmpty && readingsEmpty;
  }

  /// Pushes all local decks, cards and readings to the cloud store.
  /// The JSON carries the LOCAL ids (deck_id / card_ids refer to local
  /// sqflite ids); the downloading device remaps them by name.
  Future<void> uploadFromLocal() async {
    final token = _sessionToken();
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

    await _api.saveData(token, <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'decks': decks.map((deck) => deck.toMap()).toList(),
      'cards': cards,
      'readings': readings.map((reading) => reading.toMap()).toList(),
    });
  }

  /// Imports the cloud data into the local database. Does nothing when
  /// the cloud store is empty. NEVER deletes local data.
  ///
  /// ID REMAPPING (critical): the ids in the cloud data are the OTHER
  /// device's local sqflite ids and must never be reused as identity
  /// here. Decks are matched by (name, created_date), cards by (deck,
  /// name), readings by (name, date); everything new is inserted
  /// without an id so sqflite assigns fresh local ids, and reading card
  /// ids are resolved back to local card ids by card NAME.
  Future<void> downloadToLocal() async {
    final data = await _api.getData(_sessionToken());
    if (_isEmptyData(data)) return;

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

    // NORMALISATION (i18n): warm the translation cache for
    // every deck just downloaded, so it displays in the active
    // system language when the user opens it. Best-effort: any
    // failure is swallowed and the deck stays usable in its
    // original language. The stored source text is NEVER
    // rewritten — translations live in the Worker's permanent
    // `deck_translations` table + the in-memory cache
    // (see TranslationService).
    try {
      final target = targetLanguageCode?.call() ?? 'vi';
      for (final newDeckId in deckIdMap.values.toSet()) {
        final deck = localDecks.firstWhere(
          (d) => d.id == newDeckId,
          orElse: () => TarotDeckModel(
            name: '',
            createdDate: DateTime.now(),
          ),
        );
        final cards = await db.getCardsByDeckId(newDeckId);
        if (cards.isEmpty) continue;
        await _translationService.warmCache(
          cards,
          deckName: deck.name,
          sourceLang: detectDeckLanguage(deck.name, cards),
          targetLang: target,
        );
        // PERMANENT STORE (write-time, V2): store the downloaded
        // deck's translations permanently for all four languages
        // too — any signed-in user, owner decided server-side
        // from the session (a deck that is later submitted is
        // covered again server-side at submit). Best-effort and
        // fire-and-forget — a failure changes nothing here.
        unawaited(
          _translationService.storeDeckTranslations(
            cards,
            deckId: newDeckId,
            deckName: deck.name,
            sourceLang: detectDeckLanguage(deck.name, cards),
          ),
        );
      }
    } catch (_) {
      // Warm-up must never fail a sync.
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

  /// The login policy. Throws [TarotdeskApiException] on any network/API
  /// failure; the caller (login screen) catches and ignores it silently.
  Future<CloudSyncOutcome> syncAfterLogin() async {
    final decks = await DatabaseHelper.instance.getDecks();
    final readings = await DatabaseHelper.instance.getReadings();
    final hasUserData = decks.any((deck) => deck.name != _baseDeckName) ||
        readings.isNotEmpty;

    final data = await _api.getData(_sessionToken());
    if (_isEmptyData(data)) {
      if (hasUserData) {
        await uploadFromLocal();
        return CloudSyncOutcome.uploaded;
      }
      return CloudSyncOutcome.noData;
    }

    if (!hasUserData) {
      await downloadToLocal();
      return CloudSyncOutcome.downloaded;
    }

    // Both sides have data: never auto-overwrite in either direction.
    // (There is no manual sync button any more; the automatic
    // login/reload sync simply leaves both sides as they are.)
    return CloudSyncOutcome.upToDate;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value, String field) {
    if (value == null) return const <Map<String, dynamic>>[];
    if (value is! List) {
      throw TarotdeskApiException('server', 'Sync data field "$field" is not a list');
    }
    final result = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        result.add(item);
      } else if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      } else {
        throw TarotdeskApiException(
            'server', 'Sync data field "$field" has an invalid entry');
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
