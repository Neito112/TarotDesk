import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/translation_service.dart';
import '../../data/models/tarot_deck.dart';
import '../../logic/settings_provider.dart';

/// Shared display widgets that show a deck's name / a reading's
/// name in the active system language.
///
/// Both widgets follow the [LocalizedCardName] pattern in
/// `localized_card_text.dart`: they read the single shared
/// [TranslationService] from the provider tree
/// (`context.read<TranslationService>()`) and watch the active
/// language (`SettingsProvider.language.code`). The [Future] for a
/// name is cached per (name, target language) and is only
/// re-created when the name or the active language changes, so
/// unrelated rebuilds never re-translate and never flicker.
///
/// While the translation is loading (or if it is unavailable)
/// the ORIGINAL text is shown, so the widgets never throw and
/// never render blank. When the text could not be translated
/// and its source language differs from the target language, a
/// small dim source-language badge (e.g. " · vi") is appended —
/// language codes only, no new localization keys, no
/// hand-translated strings anywhere in this file.
///
/// The ONE exception is the seeded base deck: its name is a
/// fixed app string, not user content, so [LocalizedDeckName]
/// shows it via the `deck.baseName` localization key
/// (`SettingsProvider.tr`) instead of machine translation. The
/// STORED deck name is never changed — only the displayed text.
///
/// Deck / reading names are USER content, so they go through the
/// same machine-translation path as card content
/// ([TranslationService.translate], server-side MT + D1 cache).
/// The stored values are never overwritten and no lookup or
/// comparison against a name is ever changed — only display.

/// State shared by [LocalizedDeckName] and [LocalizedReadingName]:
/// caches one translation future per (name, target language) and
/// builds the displayed [Text] from the translation result.
mixin _LocalizedNameStateMixin<T extends StatefulWidget> on State<T> {
  Future<TranslationResult>? _future;
  String? _name;
  String? _targetLang;

  /// (Re)creates the cached future when the name or the target
  /// language changed. Returns the future to feed a
  /// [FutureBuilder], or null when no service is available (the
  /// caller then renders the original text).
  Future<TranslationResult>? futureForName(
    BuildContext context,
    String name,
  ) {
    final targetLang = context.watch<SettingsProvider>().language.code;
    if (_future == null || _name != name || _targetLang != targetLang) {
      _name = name;
      _targetLang = targetLang;
      try {
        _future = context
            .read<TranslationService>()
            .translate(name, targetLang: targetLang);
      } catch (_) {
        // No shared service available: fall through and render
        // the original text below; never throw, never blank.
        _future = null;
      }
    }
    return _future;
  }

  /// Builds the [Text] for one localized name.
  ///
  /// [original] is shown while loading / on any failure. When
  /// [result] is present but untranslated and its source
  /// language differs from the target language the future was
  /// created for, a dim " · <lang>" badge is appended.
  Widget buildNameText({
    required String original,
    required TranslationResult? result,
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final displayText = result == null ? original : result.text;
    final showBadge = result != null &&
        !result.translated &&
        result.sourceLang.isNotEmpty &&
        result.sourceLang != _targetLang;
    if (!showBadge) {
      return Text(
        displayText,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    final baseSize = style?.fontSize ?? 14.0;
    final baseColor = style?.color;
    return Text.rich(
      TextSpan(
        text: displayText,
        style: style,
        children: [
          TextSpan(
            text: ' · ${result.sourceLang}',
            style: TextStyle(
              fontSize: baseSize * 0.8,
              color: baseColor != null
                  ? baseColor.withOpacity(0.55)
                  : Colors.white60,
            ),
          ),
        ],
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// A deck's name in the active system language.
///
/// The seeded base deck (`Bộ bài cơ bản`) shows the localized
/// `deck.baseName` label. Any other deck name is machine
/// translated via [TranslationService]; the original name shows
/// while the translation loads (or if it is unavailable), with a
/// dim source-language badge when it could not be translated.
class LocalizedDeckName extends StatefulWidget {
  const LocalizedDeckName({
    super.key,
    required this.deck,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : name = null;

  /// Name-only form, for rows that only have a name string (a
  /// shared-deck entry, an admin list entry, a renamed deck).
  /// The seeded base deck is recognised by its fixed name, so
  /// no flag is needed at the call site.
  const LocalizedDeckName.fromName({
    super.key,
    required this.name,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : deck = null;

  final TarotDeckModel? deck;
  final String? name;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<LocalizedDeckName> createState() => _LocalizedDeckNameState();
}

class _LocalizedDeckNameState extends State<LocalizedDeckName>
    with _LocalizedNameStateMixin<LocalizedDeckName> {
  String get _resolvedName => widget.deck?.name ?? widget.name ?? '';

  bool get _isBaseDeck => _resolvedName == kBaseDeckName;

  @override
  Widget build(BuildContext context) {
    final name = _resolvedName;
    if (name.isEmpty) {
      // Nothing stored: render exactly what the old raw Text
      // rendered (empty), never invent a label.
      return Text(
        name,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }
    if (_isBaseDeck) {
      // Fixed app string: localized label, rebuilt automatically
      // when the language changes (watch below).
      final settings = context.watch<SettingsProvider>();
      return Text(
        settings.tr('deck.baseName'),
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }
    final future = futureForName(context, name);
    return FutureBuilder<TranslationResult>(
      future: future,
      builder: (context, snapshot) {
        return buildNameText(
          original: name,
          result: snapshot.data,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );
      },
    );
  }
}

/// A reading's name in the active system language.
///
/// Reading names are user content (including the Vietnamese
/// defaults `Lượt Trải Bài Mới` / `Trải Bài Không Tên`), so they
/// are machine translated via [TranslationService] like any
/// other user-typed name. The original name shows while the
/// translation loads (or if it is unavailable), with a dim
/// source-language badge when it could not be translated.
class LocalizedReadingName extends StatefulWidget {
  const LocalizedReadingName({
    super.key,
    required this.name,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String name;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<LocalizedReadingName> createState() => _LocalizedReadingNameState();
}

class _LocalizedReadingNameState extends State<LocalizedReadingName>
    with _LocalizedNameStateMixin<LocalizedReadingName> {
  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    if (name.isEmpty) {
      return Text(
        name,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }
    final future = futureForName(context, name);
    return FutureBuilder<TranslationResult>(
      future: future,
      builder: (context, snapshot) {
        return buildNameText(
          original: name,
          result: snapshot.data,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );
      },
    );
  }
}

/// Splits a translated template on [placeholder] and returns the
/// inline spans for a [Text.rich]: the template's own text as
/// [TextSpan]s (with [style]) and [nameWidget] — a
/// [LocalizedDeckName] or [LocalizedReadingName] — slotted in
/// wherever the placeholder was. The stored name is never
/// interpolated into the string; only the displayed widget is
/// localized.
///
/// Used where a name is embedded inside a translated sentence
/// (delete-confirm dialogs, the home history footer), where a
/// plain `Text` cannot hold a widget. If the template contains
/// no placeholder, the whole template is returned as one span.
List<InlineSpan> templateWithLocalizedName({
  required String template,
  required String placeholder,
  required Widget nameWidget,
  TextStyle? style,
}) {
  final parts = template.split(placeholder);
  if (parts.length < 2) {
    return <InlineSpan>[TextSpan(text: template, style: style)];
  }
  final spans = <InlineSpan>[];
  for (var i = 0; i < parts.length; i++) {
    if (i > 0) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: nameWidget,
        ),
      );
    }
    if (parts[i].isNotEmpty) {
      spans.add(TextSpan(text: parts[i], style: style));
    }
  }
  return spans;
}
