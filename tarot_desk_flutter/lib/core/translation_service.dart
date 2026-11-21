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
/// 3. Two caches, so the same text is never translated twice:
///    a shared D1 `translations` table on the Worker (one
///    translation serves every user), and an in-memory cache here
///    (one session). A local sqflite cache is a future step, not
///    done here — see REPORT.md.
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
library;

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
  /// `'cache'`, or `'none'` (original shown).
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
  })  : _sessionToken = sessionToken,
        _targetLanguageCode = targetLanguageCode;

  final TarotdeskApiService _api;
  final String? Function()? _sessionToken;
  final String Function() _targetLanguageCode;

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
  Future<int> warmCache(
    List<TarotCardModel> cards, {
    String? deckName,
    String? sourceLang,
    String? targetLang,
  }) async {
    final target = (targetLang ?? targetLanguageCode).toLowerCase();
    final source = sourceLang ??
        (deckName != null ? detectDeckLanguage(deckName, cards) : null);
    if (source != null && source.toLowerCase() == target) return 0;
    var translated = 0;
    try {
      // Batch the names + meanings of the whole deck into as
      // few Worker calls as possible: one call per 20 strings.
      final texts = <String>[];
      for (final card in cards) {
        texts.add(card.name);
        texts.add(card.meaning);
      }
      const batchSize = 20;
      for (var i = 0; i < texts.length; i += batchSize) {
        final batch = texts.sublist(
          i,
          i + batchSize > texts.length ? texts.length : i + batchSize,
        );
        final results = await _api.translateTexts(
          sessionToken: _sessionToken?.call(),
          texts: batch,
          targetLang: target,
          sourceLang: source,
        );
        for (var j = 0; j < results.length; j++) {
          if (results[j].translated) translated++;
          _cachePut(
            _cacheKey(batch[j], source ?? 'auto', target),
            TranslationResult(
              text: results[j].text,
              sourceLang: results[j].sourceLang,
              translated: results[j].translated,
              engine: results[j].engine,
              fromCache: results[j].fromCache,
            ),
          );
        }
      }
    } catch (_) {
      // Best-effort warming: a failed warm-up only means the
      // first view of the deck translates on demand instead.
    }
    return translated;
  }
}
