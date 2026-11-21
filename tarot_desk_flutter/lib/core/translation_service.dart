import '../data/datasources/tarotdesk_api_service.dart';
import '../data/models/tarot_card.dart';

/// Normalisation layer for deck / card CONTENT (names + meanings).
///
/// Problem it solves: [AppStrings] (localization.dart) translates the
/// UI chrome only. Deck and card text is user data — it arrives in
/// many languages (typed in by the user, imported from another
/// device, downloaded from the shared library, or seeded in
/// Vietnamese) — and was shown verbatim, so switching the system
/// language left most of the app in Vietnamese.
///
/// Design (chosen after comparing the options in
/// `i18n/REPORT.md`):
///
/// 1. The SOURCE text is never overwritten. A translation is a
///    separate, cached view of the source, keyed by
///    (source text, source language, target language). The stored
///    deck/card rows keep exactly what the author wrote.
/// 2. Translation happens server-side, in the existing Cloudflare
///    Worker (`POST /translate`, see `i18n/worker/translate-route.js`).
///    Primary engine: Workers AI `@cf/meta/m2m100-1.2b` — no new
///    vendor, no API key, inside the free 10,000 Neurons/day.
///    Fallback engine: Google Cloud Translation, called by the
///    Worker only, with the key as a Worker secret
///    (`GOOGLE_TRANSLATE_API_KEY`, never in app code). If neither
///    engine is available the original text is shown, marked with
///    its source language — the app never crashes and never shows
///    an empty card.
/// 3. Two places hold translations, and they are NOT the same thing:
///    (a) the shared D1 `translations` table on the Worker serves
///    ONLY the ad-hoc `POST /translate` endpoint (one translation
///    serves every user, keyed by content hash — a cache);
///    (b) a deck's translations are PERMANENT per-deck / per-user
///    data in the D1 `deck_translations` table, keyed by
///    (deck_key, card_id, lang) with an owner — never evicted,
///    never keyed by content hash (see [TranslationService.
///    storeDeckTranslations]). Plus an in-memory cache here (one
///    session). A local sqflite cache is a future step, not done
///    here — see REPORT.md.
/// 5. Translation is also STORED PERMANENTLY at write time (see
///    [TranslationService.storeDeckTranslations]): when a deck is
///    created, edited or imported, its texts are translated into
///    ALL FOUR UI languages in the background and stored as
///    permanent rows in the Worker's `deck_translations` table
///    (owner: 'shared' for shared data, the author's email for
///    personal data — decided server-side from the session).
///    Switching language then reads the stored rows
///    ([preloadDeckTranslations] + `GET /deck-translations`)
///    instead of translating everything at switch time (which
///    does not scale to hundreds of decks). The server does the
///    same on submit; APPROVAL only moves the deck record and
///    never re-translates. The PR #43 loading dialog stays as the
///    fallback for anything not stored yet — nothing here removes
///    it.
/// 4. Translation is LAZY + WARMED, never blocking:
///    * display path — [localizeCard] translates only the card
///      being shown, and only when its source language differs
///      from the active language;
///    * import path — [warmCache] fires after a deck is added
///      (add_deck_screen) or downloaded (cloud_sync_service), so
///      the translations are already cached when the user opens
///      the deck. Both call sites are best-effort: any failure is
///      swallowed and the original text is shown.
///
/// Language detection: Workers AI m2m100 needs an explicit
/// `source_lang` and ships no detector, so detection is a small
/// script-based heuristic ([detectLanguage]) plus the author's
/// language when known (the deck's own language, or `'vi'` for the
/// seeded base deck). It is deliberately conservative: when it
/// cannot tell, it returns `null` and the Worker auto-detects
/// (Google fallback) or defaults to English for m2m100 — never a
/// confident wrong guess. Short card names are the weak case;
/// [detectDeckLanguage] votes across the whole deck, which is
/// much more reliable than one name.
///
/// This file has NO new package dependencies and imports no
/// `dart:io` — it builds for Flutter web. No API key or secret
/// lives here (or anywhere in the app).

/// The seeded base deck ships in Vietnamese (see
/// `DatabaseHelper._seedDefaultCards` / `defaultTarotMeanings`).
/// It is treated as source-language `'vi'` content like any other
/// deck — it is NOT hand-translated here; it goes through the
/// same [TranslationService] path when the active language is
/// not Vietnamese.
const String kBaseDeckSourceLanguage = 'vi';

/// Name of the seeded deck. A data identifier, not UI text —
/// same constant as `CloudSyncService._baseDeckName`.
const String kBaseDeckName = 'Bộ bài cơ bản';

/// Languages the app UI supports (mirrors `AppLanguage.code`).
/// m2m100 covers all five; anything else is passed through to
/// the Worker, which answers with the original text if the
/// engine cannot serve it.
const List<String> kSupportedContentLanguages = <String>[
  'vi',
  'en',
  'zh',
  'ko',
  'ja',
];

/// Target languages for permanent deck translation (server-side):
/// every UI language except the source. Vietnamese is the source
/// language of the seeded base deck and of most user decks, so it
/// is never a target; the Worker skips any target equal to the
/// detected source anyway. (Kept here for documentation; the
/// Worker owns the list.)
const List<String> kDeckTranslationTargetLanguages = <String>[
  'en',
  'zh',
  'ko',
  'ja',
];

/// Fixed deck_key of the seeded base deck ('Bộ bài cơ bản'). Its
/// translations are shared data (owner 'shared'), stored once by
/// the seed script — never by a regular user (the Worker answers
/// 403 for a non-admin storing under this key).
const String kBaseDeckKey = 'base';

/// card_id of the deck-NAME row in `deck_translations`: its `name`
/// holds the translated deck name, `meaning` is always ''.
const int kDeckNameCardId = -1;

/// deck_key for one user's own deck: 'user-<google sub>-<local
/// deck id>'. The google_sub makes the key globally unique (the
/// table's primary key has no owner column, so a bare local id
/// would collide across users); the local deck id keeps it stable
/// on this device. Returns null when there is no signed-in user
/// (guests have no server identity — see [TranslationService.
/// storeDeckTranslations]) or no deck id.
String? deckKeyForPersonalDeck({
  required String? userSub,
  required int? deckId,
}) {
  if (userSub == null || userSub.isEmpty || deckId == null) return null;
  return 'user-$userSub-$deckId';
}

/// deck_key for a LOCAL deck, for the READ side (fetching /
/// preloading its stored translations): the base deck uses its
/// fixed key, every other deck uses its personal key. NOTE: this
/// is NOT the store-side key — storing always uses the personal
/// key (see [TranslationService.storeDeckTranslations]); only the
/// seed script ever stores under 'base', as admin. A user deck
/// that happens to be named exactly like the base deck reads the
/// shared base rows — the display wiring therefore tries the
/// personal key first and falls back to this key (see REPORT.md).
/// (The durable fix is a persisted UUID deck_key on the local
/// deck row; see REPORT.md.)
String? deckKeyForLocalDeck({
  required String? userSub,
  required int? deckId,
  required String deckName,
}) {
  if (deckName == kBaseDeckName) return kBaseDeckKey;
  return deckKeyForPersonalDeck(userSub: userSub, deckId: deckId);
}

/// One translated string, as returned by the Worker.
class TranslationResult {
  const TranslationResult({
    required this.text,
    required this.sourceLang,
    required this.translated,
    required this.engine,
    required this.fromCache,
  });

  /// The text to display: the translation, or the original when
  /// translation was unavailable / unnecessary.
  final String text;

  /// Detected or declared source language (ISO 639-1, e.g. 'vi').
  final String sourceLang;

  /// False when [text] is the untranslated original (engine
  /// unavailable, unconfigured, or source == target).
  final bool translated;

  /// Which engine produced it: `'workers-ai'`, `'google'`,
  /// `'cache'`, `'stored'` (a permanent `deck_translations` row
  /// preloaded by [TranslationService.preloadDeckTranslations]),
  /// or `'none'` (original shown).
  final String engine;

  /// True when the Worker served this from the D1 cache
  /// (no AI call was spent).
  final bool fromCache;
}

/// A card ready to display in the active language.
///
/// [name] / [meaning] are the translated strings when available,
/// otherwise the card's original text. [translated] is false in
/// the fallback case; the UI can show a compact language badge
/// from [sourceLang] + [targetLang] (language codes only — no new
/// localization keys are needed for it).
class LocalizedCard {
  const LocalizedCard({
    required this.card,
    required this.name,
    required this.meaning,
    required this.sourceLang,
    required this.targetLang,
    required this.translated,
  });

  final TarotCardModel card;
  final String name;
  final String meaning;
  final String sourceLang;
  final String targetLang;
  final bool translated;
}

// ------------------------------------------------------------------
// Language detection (script heuristic — see file doc comment).
// ------------------------------------------------------------------

bool _isHangul(int rune) => rune >= 0xAC00 && rune <= 0xD7A3;

bool _isHiraganaOrKatakana(int rune) =>
    (rune >= 0x3040 && rune <= 0x30FF) || rune == 0x30FC;

bool _isHan(int rune) =>
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0xF900 && rune <= 0xFAFF);

bool _isVietnameseDiacritic(int rune) {
  // Precomposed Vietnamese vowels (à á ả ã ạ ă â đ ê ô ơ ư …)
  // plus combining marks U+0300–U+036F.
  return (rune >= 0x00C0 && rune <= 0x01B0 && _vietnameseLetters.contains(rune)) ||
      rune == 0x0110 || // Đ
      rune == 0x0111 || // đ
      (rune >= 0x0300 && rune <= 0x036F);
}

const Set<int> _vietnameseLetters = <int>{
  0x00C0, 0x00C1, 0x00C2, 0x00C3, 0x00C8, 0x00C9, 0x00CA, 0x00CC, 0x00CD,
  0x00D2, 0x00D3, 0x00D4, 0x00D5, 0x00D9, 0x00DA, 0x00DD, 0x00E0, 0x00E1,
  0x00E2, 0x00E3, 0x00E8, 0x00E9, 0x00EA, 0x00EC, 0x00ED, 0x00F2, 0x00F3,
  0x00F4, 0x00F5, 0x00F9, 0x00FA, 0x00FD, 0x0102, 0x0103, 0x01A0, 0x01A1,
  0x01AF, 0x01B0,
};

/// Words that only occur in Vietnamese running text. Used as a
/// tie-breaker for Latin-script text with no diacritics (e.g. a
/// short card name typed without tones).
const Set<String> _vietnameseWords = <String>{
  'cua', 'va', 'la', 'bai', 'nguoi', 'tinh', 'yeu', 'cong', 'viec',
  'cuoc', 'song', 'moi', 'quan', 'he', 'trong', 'ngoai', 'nhung',
  'khong', 'duoc', 'chien', 'thang', 'hoang', 'hau', 'vua', 'chua',
};

/// Detect the language of [text], or `null` when it cannot be
/// told reliably. Never throws. Order matters: a script that
/// only one language uses wins outright; Latin script is
/// ambiguous, so Vietnamese is recognised by diacritics / common
/// words and everything else falls back to `null` (the Worker
/// then auto-detects) rather than a guessed `'en'`.
String? detectLanguage(String text) {
  if (text.trim().isEmpty) return null;
  var hangul = 0;
  var kana = 0;
  var han = 0;
  var vietDiacritics = 0;
  var latinLetters = 0;
  for (final rune in text.runes) {
    if (_isHangul(rune)) {
      hangul++;
    } else if (_isHiraganaOrKatakana(rune)) {
      kana++;
    } else if (_isHan(rune)) {
      han++;
    } else if (_isVietnameseDiacritic(rune)) {
      vietDiacritics++;
    } else if ((rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A)) {
      latinLetters++;
    }
  }
  if (hangul > 0) return 'ko';
  if (kana > 0) return 'ja';
  if (han > 0) return 'zh';
  if (vietDiacritics > 0) return 'vi';
  if (latinLetters > 0) {
    final words = text
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((w) => w.isNotEmpty);
    var vietHits = 0;
    var total = 0;
    for (final word in words) {
      total++;
      if (_vietnameseWords.contains(word)) vietHits++;
    }
    if (total > 0 && vietHits * 2 >= total && vietHits >= 2) return 'vi';
    return null;
  }
  return null;
}

/// Vote for one source language across a whole deck: concatenate
/// the deck name + every card name + the first 200 chars of each
/// meaning, then [detectLanguage]. A deck votes much more
/// reliably than a single short card name. Returns `null` when
/// the vote is inconclusive.
String? detectDeckLanguage(String deckName, List<TarotCardModel> cards) {
  final buffer = StringBuffer(deckName);
  for (final card in cards) {
    buffer.write(' ');
    buffer.write(card.name);
    buffer.write(' ');
    final meaning = card.meaning;
    buffer.write(
      meaning.length > 200 ? meaning.substring(0, 200) : meaning,
    );
  }
  return detectLanguage(buffer.toString());
}

/// Split long text into translatable segments.
///
/// Workers AI m2m100 drops all but one sentence of a
/// multi-sentence input, so a long card meaning must never be
/// sent as one block. Segments split on blank lines first, then
/// on sentence boundaries (`. ! ?` + space, and the Vietnamese
/// `...`), and are capped at ~800 characters; the pieces are
/// translated one by one and re-joined with the same separators
/// they were split on. Short text comes back as a single segment.
List<String> segmentText(String text) {
  final segments = <String>[];
  for (final paragraph in text.split('\n')) {
    final trimmed = paragraph.trim();
    if (trimmed.isEmpty) {
      segments.add('');
      continue;
    }
    if (trimmed.length <= 800) {
      segments.add(trimmed);
      continue;
    }
    // Long paragraph: split on sentence boundaries, then
    // re-pack sentences into <=800-char chunks.
    final sentences = trimmed.split(RegExp(r'(?<=[.!?…])\s+'));
    final current = StringBuffer();
    for (final sentence in sentences) {
      if (current.isEmpty) {
        current.write(sentence);
      } else if (current.length + 1 + sentence.length <= 800) {
        current.write(' ');
        current.write(sentence);
      } else {
        segments.add(current.toString());
        current.clear();
        current.write(sentence);
      }
    }
    if (current.isNotEmpty) segments.add(current.toString());
  }
  // Drop the trailing empty segment a trailing newline creates;
  // interior '' entries are real blank lines and are kept.
  while (segments.length > 1 && segments.last.isEmpty) {
    segments.removeLast();
  }
  return segments.isEmpty ? <String>[text] : segments;
}

// ------------------------------------------------------------------
// The service.
// ------------------------------------------------------------------

/// Normalises deck/card content into [targetLanguageCode].
///
/// Construct once per session (the in-memory cache lives here)
/// and reuse it. [sessionToken] is a callback so the token is
/// read fresh on every call — the service never stores a token.
/// When there is no signed-in user the callback returns null and
/// the Worker serves the request under the anonymous cap (see
/// `worker/translate-route.js`); guests still get translations,
/// just fewer of them per day.
class TranslationService {
  TranslationService(
    this._api, {
    String? Function()? sessionToken,
    required String Function() targetLanguageCode,
    String? Function()? userSub,
  })  : _sessionToken = sessionToken,
        _targetLanguageCode = targetLanguageCode,
        _userSub = userSub;

  final TarotdeskApiService _api;
  final String? Function()? _sessionToken;
  final String Function() _targetLanguageCode;

  /// The signed-in user's Google `sub` (stable per account), or
  /// null for guests. Used only to derive the personal deck_key
  /// ([deckKeyForPersonalDeck]) — the OWNER of the stored rows is
  /// still decided server-side from the session, never from this
  /// value. Null when the caller did not provide one.
  final String? Function()? _userSub;

  /// In-memory cache: "$sourceLang|$targetLang|$text" -> result.
  /// Bounded: oldest entries are dropped past 500, so a long
  /// session cannot grow memory without limit.
  final Map<String, TranslationResult> _memoryCache =
      <String, TranslationResult>{};
  static const int _maxMemoryEntries = 500;

  String get targetLanguageCode => _targetLanguageCode();

  String _cacheKey(String text, String sourceLang, String targetLang) =>
      '$sourceLang|$targetLang|$text';

  void _cachePut(String key, TranslationResult result) {
    if (_memoryCache.length >= _maxMemoryEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = result;
  }

  /// Translate one string into [targetLang] (defaults to the
  /// active system language). Never throws: on any failure the
  /// original text is returned with `translated: false`.
  Future<TranslationResult> translate(
    String text, {
    String? sourceLang,
    String? targetLang,
  }) async {
    final target = (targetLang ?? targetLanguageCode).toLowerCase();
    final source = (sourceLang ?? detectLanguage(text) ?? 'auto')
        .toLowerCase();
    if (text.trim().isEmpty) {
      return TranslationResult(
        text: text,
        sourceLang: source,
        translated: false,
        engine: 'none',
        fromCache: false,
      );
    }
    // Source already equals target: nothing to do. ('auto' is
    // not equal to any target, so it still goes to the Worker,
    // which detects it there.)
    if (source == target) {
      return TranslationResult(
        text: text,
        sourceLang: source,
        translated: false,
        engine: 'none',
        fromCache: false,
      );
    }
    final key = _cacheKey(text, source, target);
    final cached = _memoryCache[key];
    if (cached != null) return cached;

    try {
      // Segment first (see [segmentText]): one Worker call with
      // all segments, so a long meaning costs one round-trip.
      final segments = segmentText(text);
      final translatedSegments = await _api.translateTexts(
        sessionToken: _sessionToken?.call(),
        texts: segments,
        targetLang: target,
        sourceLang: source == 'auto' ? null : source,
      );
      if (translatedSegments.length != segments.length) {
        throw const TarotdeskApiException(
          'server',
          'Translation returned the wrong number of segments.',
        );
      }
      final buffer = StringBuffer();
      var anyTranslated = false;
      var anyCached = false;
      var engine = 'none';
      var detectedSource = source;
      for (var i = 0; i < segments.length; i++) {
        if (i > 0) buffer.write('\n');
        final seg = translatedSegments[i];
        buffer.write(seg.text);
        if (seg.translated) anyTranslated = true;
        if (seg.fromCache) anyCached = true;
        if (seg.engine != 'none') engine = seg.engine;
        if (seg.sourceLang.isNotEmpty) detectedSource = seg.sourceLang;
      }
      final result = TranslationResult(
        text: buffer.toString(),
        sourceLang: detectedSource,
        translated: anyTranslated,
        engine: engine,
        fromCache: anyCached,
      );
      _cachePut(key, result);
      return result;
    } on TarotdeskApiException {
      // Worker down / unconfigured / quota spent: show the
      // original, marked with its source language.
      return TranslationResult(
        text: text,
        sourceLang: source,
        translated: false,
        engine: 'none',
        fromCache: false,
      );
    } catch (_) {
      return TranslationResult(
        text: text,
        sourceLang: source,
        translated: false,
        engine: 'none',
        fromCache: false,
      );
    }
  }

  /// Translate a whole card (name + meaning) into the active
  /// language in a single Worker call. [sourceLang] is the
  /// deck's language when known — pass [kBaseDeckSourceLanguage]
  /// for the seeded base deck, or a [detectDeckLanguage] vote
  /// for an imported deck; null lets detection run per string.
  /// Name and meaning are translated through [translate], so
  /// each benefits from the in-memory cache and the segmenting
  /// in [segmentText].
  Future<LocalizedCard> localizeCard(
    TarotCardModel card, {
    String? sourceLang,
    String? targetLang,
  }) async {
    final target = (targetLang ?? targetLanguageCode).toLowerCase();
    final source = sourceLang ?? detectLanguage('${card.name} ${card.meaning}');
    // Fast path: nothing to translate.
    if (source != null && source.toLowerCase() == target) {
      return LocalizedCard(
        card: card,
        name: card.name,
        meaning: card.meaning,
        sourceLang: source,
        targetLang: target,
        translated: false,
      );
    }
    final nameResult = await translate(
      card.name,
      sourceLang: source,
      targetLang: target,
    );
    final meaningResult = await translate(
      card.meaning,
      sourceLang: source,
      targetLang: target,
    );
    return LocalizedCard(
      card: card,
      name: nameResult.text,
      meaning: meaningResult.text,
      sourceLang: meaningResult.sourceLang.isNotEmpty
          ? meaningResult.sourceLang
          : (source ?? kBaseDeckSourceLanguage),
      targetLang: target,
      translated: nameResult.translated || meaningResult.translated,
    );
  }

  /// Warm the caches for a deck without blocking the caller.
  /// Used after a deck is added (add_deck_screen) or downloaded
  /// (cloud_sync_service): the deck's cards are translated in
  /// the background, so opening the deck later reads straight
  /// from the D1 / in-memory cache. Best-effort — every failure
  /// is swallowed; the deck is fully usable untranslated.
  /// Returns the number of translated strings (names +
  /// meanings) that came back translated.
  ///
  /// [onProgress] is called after each batch with
  /// (strings processed so far, total strings). A failed batch
  /// still counts as processed — it is skipped, not retried —
  /// so a caller showing a loading dialog always reaches 100%
  /// and the flow never hangs. Each card contributes exactly
  /// 2 strings (name + meaning), so cards done = strings ~/ 2.
  Future<int> warmCache(
    List<TarotCardModel> cards, {
    String? deckName,
    String? sourceLang,
    String? targetLang,
    void Function(int doneStrings, int totalStrings)? onProgress,
  }) async {
    final target = (targetLang ?? targetLanguageCode).toLowerCase();
    final source = sourceLang ??
        (deckName != null ? detectDeckLanguage(deckName, cards) : null);
    if (source != null && source.toLowerCase() == target) return 0;
    var translated = 0;
    // Batch the names + meanings of the whole deck into as
    // few Worker calls as possible: one call per 20 strings.
    final texts = <String>[];
    for (final card in cards) {
      texts.add(card.name);
      texts.add(card.meaning);
    }
    const batchSize = 20;
    var doneStrings = 0;
    for (var i = 0; i < texts.length; i += batchSize) {
      final batch = texts.sublist(
        i,
        i + batchSize > texts.length ? texts.length : i + batchSize,
      );
      // WIRING (display path): skip strings already in the in-memory
      // cache — they were seeded by [preloadDeckTranslations] from
      // the permanent `deck_translations` table. Without this, the
      // bulk pass would re-translate them via POST /translate and
      // OVERWRITE the stored rows with the ad-hoc MT result.
      // Cached strings still count toward progress (they are done).
      final uncached = batch
          .where((text) =>
              _memoryCache[_cacheKey(text, source ?? 'auto', target)] ==
              null)
          .toList(growable: false);
      try {
        if (uncached.isEmpty) continue;
        final results = await _api.translateTexts(
          sessionToken: _sessionToken?.call(),
          texts: uncached,
          targetLang: target,
          sourceLang: source,
        );
        for (var j = 0; j < results.length; j++) {
          if (results[j].translated) translated++;
          _cachePut(
            _cacheKey(uncached[j], source ?? 'auto', target),
            TranslationResult(
              text: results[j].text,
              sourceLang: results[j].sourceLang,
              translated: results[j].translated,
              engine: results[j].engine,
              fromCache: results[j].fromCache,
            ),
          );
        }
      } catch (_) {
        // One failed batch (Worker down / timeout / quota) only
        // skips that batch — the remaining batches still run,
        // and the skipped cards translate on demand later.
      } finally {
        // Progress always advances past this batch (translated,
        // cached, or skipped) so a loading dialog reaches 100%.
        doneStrings += batch.length;
        onProgress?.call(doneStrings, texts.length);
      }
    }
    return translated;
  }

  /// Store a deck's translations PERMANENTLY at write time
  /// ([kDeckTranslationTargetLanguages]), in the background.
  ///
  /// This is the write-time half of the V2 design: instead of
  /// translating everything when the user switches language
  /// (which does not scale to hundreds of decks), the deck's texts
  /// are translated the moment the deck is created, edited or
  /// imported, and stored as permanent rows in the Worker's
  /// `deck_translations` table — keyed by (deck_key, card_id,
  /// lang), owned by 'shared' for shared data or by the author's
  /// email for personal data (decided server-side from the
  /// session). The language switch later reads those stored rows
  /// ([preloadDeckTranslations]); the PR #43 loading dialog stays
  /// as the fallback for anything not stored yet.
  ///
  /// Fire-and-forget: callers wrap this in `unawaited` (it never
  /// blocks the user) and every failure is swallowed here — a
  /// failed store only means the deck translates on demand later.
  /// Returns the number of cards accepted for storing (0 when
  /// nothing was stored). Each call sends at most 100 texts /
  /// 40,000 chars, mirroring the Worker's authed caps.
  ///
  /// [deckKey] overrides the derived key (used by the seed flow
  /// for the base deck); otherwise the key is the PERSONAL key
  /// derived from [deckId] + the signed-in user's sub
  /// ([deckKeyForPersonalDeck]) — the app never stores under
  /// 'base'. [deckName] is sent as the deck-name row on a
  /// whole-deck store and feeds source-language detection.
  /// stores ONE card only, at that 0-based position in [cards]
  /// (a single-card edit — only the changed card is re-translated,
  /// the rest of the deck is untouched); null stores the whole
  /// deck, positions being the list order, plus the deck-name row.
  ///
  /// Guests (no session token, no google_sub) have no server
  /// identity, so their decks cannot have server-side personal
  /// data: this returns 0 without a network call and their decks
  /// translate on demand, exactly as before. Any signed-in user
  /// — admin or not — can store their own decks; the old V1
  /// admin-only gate is gone.
  Future<int> storeDeckTranslations(
    List<TarotCardModel> cards, {
    String? deckKey,
    int? deckId,
    String? deckName,
    int? cardIndex,
    String? sourceLang,
  }) async {
    final token = _sessionToken?.call();
    if (token == null || token.isEmpty) return 0;
    // STORE-side key: the explicit [deckKey], else the PERSONAL
    // key for this local deck. The app never stores under 'base':
    // only the seed script does (as admin). A local edit of the
    // base deck is personal data, stored under the personal key;
    // the read side tries the personal key first, then 'base'.
    final key = deckKey ??
        deckKeyForPersonalDeck(
          userSub: _userSub?.call(),
          deckId: deckId,
        );
    if (key == null || key.isEmpty) return 0;
    final source = sourceLang ??
        (deckName != null ? detectDeckLanguage(deckName, cards) : null);
    // Items to store: one card (single-card edit) or the whole deck
    // in list order. card_id is the 0-based position in the deck's
    // card list — the same order the app stores/reads them in, so
    // the rows line up with the cards on every device. For a
    // single-card store the list holds just that card and
    // [cardIndex] is its position in the full deck.
    final items = <DeckTranslationItem>[];
    if (cardIndex != null) {
      if (cards.isEmpty || cardIndex < 0) return 0;
      final card = cards.first;
      items.add(DeckTranslationItem(
        cardId: cardIndex,
        name: card.name,
        meaning: card.meaning,
      ));
    } else {
      for (var i = 0; i < cards.length; i++) {
        items.add(DeckTranslationItem(
          cardId: i,
          name: cards[i].name,
          meaning: cards[i].meaning,
        ));
      }
    }
    if (items.isEmpty && (deckName == null || deckName.trim().isEmpty)) {
      return 0;
    }
    // Chunk to the Worker's caps (100 texts / 40,000 chars per
    // call; the deck name + each card's name + meaning count as
    // one text each). A 78-card deck is 157 texts / ~74k chars,
    // so it takes 2 calls; each call returns immediately (the
    // translation itself runs in the Worker's waitUntil).
    var stored = 0;
    var i = 0;
    var firstChunk = true;
    // The deck-name row is sent only with a whole-deck store; a
    // single-card edit never re-sends it (the name did not change).
    final sendDeckName = cardIndex == null &&
        deckName != null &&
        deckName.trim().isNotEmpty;
    while (i < items.length || (firstChunk && items.isEmpty)) {
      var texts = firstChunk && sendDeckName ? 1 : 0;
      var chars = firstChunk && sendDeckName ? deckName!.length : 0;
      var j = i;
      while (j < items.length &&
          texts + 2 <= 100 &&
          chars + items[j].name.length + items[j].meaning.length <= 40000) {
        texts += 2;
        chars += items[j].name.length + items[j].meaning.length;
        j++;
      }
      // A single card longer than the char cap still goes out
      // alone — the Worker answers 413 for it and the rest of
      // the deck is unaffected.
      if (j == i && i < items.length) j = i + 1;
      try {
        final result = await _api.storeDeckTranslations(
          sessionToken: token,
          deckKey: key,
          deckName: firstChunk && sendDeckName ? deckName : null,
          items: items.sublist(i, j),
          sourceLang: source,
        );
        stored += result.queuedCards;
      } catch (_) {
        // One failed chunk only skips that chunk — the rest
        // still store, and the skipped cards translate on
        // demand later.
      }
      firstChunk = false;
      i = j;
      if (items.isEmpty) break;
    }
    return stored;
  }

  /// Fetch one deck's PERMANENT stored translations for [lang]
  /// (defaults to the active system language) from the Worker's
  /// `deck_translations` table — a fast D1 lookup by deck_key +
  /// lang, no MT call, no cache involved. Exactly one of [deckKey]
  /// (a personal/local deck, or 'base') or [sharedId] (a shared
  /// deck's server id) must be given. Returns null on any failure
  /// (including "not stored yet" — the caller falls back to the
  /// PR #43 on-demand path).
  Future<StoredDeckTranslations?> fetchDeckTranslations({
    String? deckKey,
    String? sharedId,
    String? lang,
  }) async {
    final target = (lang ?? targetLanguageCode).toLowerCase();
    try {
      return await _api.fetchDeckTranslations(
        sessionToken: _sessionToken?.call(),
        deckKey: deckKey,
        sharedId: sharedId,
        lang: target,
      );
    } catch (_) {
      return null;
    }
  }

  /// Preload a deck's stored translations into the in-memory cache
  /// so [localizeCard] serves them with no `POST /translate` call
  /// at all. Call this when a deck is opened or when the language
  /// switches, before the cards are displayed. [cards] must be the
  /// deck's cards in stored order (positions are how rows map back
  /// to cards). Returns the number of in-memory cache entries
  /// seeded (0 when nothing is stored yet — the PR #43 dialog
  /// then covers it).
  ///
  /// The rows are seeded under the same in-memory keys
  /// [localizeCard] looks up: the per-card detected source (what
  /// it uses when no [sourceLang] is passed) plus [sourceLang]
  /// itself when given, so the preload hits whichever path the
  /// display code takes.
  Future<int> preloadDeckTranslations({
    String? deckKey,
    String? sharedId,
    required List<TarotCardModel> cards,
    String? deckName,
    String? sourceLang,
    String? lang,
  }) async {
    final target = (lang ?? targetLanguageCode).toLowerCase();
    final deckSource = sourceLang ??
        (deckName != null ? detectDeckLanguage(deckName, cards) : null);
    if (deckSource != null && deckSource.toLowerCase() == target) {
      return 0;
    }
    final stored = await fetchDeckTranslations(
      deckKey: deckKey,
      sharedId: sharedId,
      lang: target,
    );
    if (stored == null) return 0;
    var loaded = 0;
    void seed(String text, String translated, String source) {
      if (text.trim().isEmpty || translated.isEmpty) return;
      _cachePut(
        _cacheKey(text, source, target),
        TranslationResult(
          text: translated,
          sourceLang: source,
          translated: true,
          engine: 'stored',
          fromCache: true,
        ),
      );
      loaded++;
    }

    void seedText(String text, String translated, String cardSource) {
      // The key localizeCard looks up (per-card detected source),
      // plus the explicit source when it differs.
      seed(text, translated, cardSource);
      if (sourceLang != null && sourceLang!.toLowerCase() != cardSource) {
        seed(text, translated, sourceLang!.toLowerCase());
      }
      if (deckSource != null && deckSource.toLowerCase() != cardSource) {
        seed(text, translated, deckSource.toLowerCase());
      }
    }

    if (deckName != null && stored.deckName.isNotEmpty) {
      seedText(
        deckName,
        stored.deckName,
        deckSource ?? detectLanguage(deckName) ?? 'auto',
      );
    }
    for (final row in stored.cards) {
      if (row.cardId < 0 || row.cardId >= cards.length) continue;
      final card = cards[row.cardId];
      final cardSource =
          deckSource ?? detectLanguage('${card.name} ${card.meaning}') ?? 'auto';
      seedText(card.name, row.name, cardSource);
      seedText(card.meaning, row.meaning, cardSource);
    }
    return loaded;
  }

  /// Preload ONE local deck's stored translations into the in-memory
  /// cache (read side) — the display-wiring entry point. Call this
  /// when a deck is opened or when the language switches, BEFORE
  /// its cards are displayed, so [localizeCard] serves the stored
  /// rows with no `/translate` call. Returns the number of entries
  /// seeded (0 when nothing is stored yet — the PR #43 dialog then
  /// covers it). Never throws. Bounded by a short timeout so a slow
  /// or unreachable Worker never blocks the screen; on timeout the
  /// caller falls back to the on-demand path.
  ///
  /// Key order (REPORT.md §6): the BASE deck reads its fixed key
  /// ([kBaseDeckKey]) only — never a personal key. Any other deck
  /// tries the PERSONAL key first (the signed-in user's own rows),
  /// then the read-side key ([deckKeyForLocalDeck]). A guest (no
  /// signed-in user, [_userSub] null) has no personal key: a
  /// personal deck preloads nothing (its translations live only in
  /// the local cache / on demand), while the base deck still loads
  /// — its rows are public shared data, readable without a session.
  /// [cards] must be the deck's cards in stored order.
  Future<int> preloadLocalDeck({
    required int? deckId,
    required String deckName,
    required List<TarotCardModel> cards,
    String? lang,
  }) async {
    try {
      return await _preloadLocalDeckInner(
        deckId: deckId,
        deckName: deckName,
        cards: cards,
        lang: lang,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => 0,
      );
    } catch (_) {
      return 0;
    }
  }

  Future<int> _preloadLocalDeckInner({
    required int? deckId,
    required String deckName,
    required List<TarotCardModel> cards,
    String? lang,
  }) async {
    // Base deck: rows live under the fixed 'base' key (shared).
    if (deckName == kBaseDeckName) {
      return preloadDeckTranslations(
        deckKey: kBaseDeckKey,
        cards: cards,
        deckName: deckName,
        lang: lang,
      );
    }
    final userSub = _userSub?.call();
    final personalKey =
        deckKeyForPersonalDeck(userSub: userSub, deckId: deckId);
    if (personalKey != null) {
      final loaded = await preloadDeckTranslations(
        deckKey: personalKey,
        cards: cards,
        deckName: deckName,
        lang: lang,
      );
      if (loaded > 0) return loaded;
    }
    final readKey = deckKeyForLocalDeck(
      userSub: userSub,
      deckId: deckId,
      deckName: deckName,
    );
    if (readKey != null && readKey != personalKey) {
      return preloadDeckTranslations(
        deckKey: readKey,
        cards: cards,
        deckName: deckName,
        lang: lang,
      );
    }
    return 0;
  }
}
