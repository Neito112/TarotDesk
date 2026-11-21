import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/translation_service.dart';
import '../../data/models/tarot_card.dart';
import '../../logic/settings_provider.dart';

/// Shared display widgets that show a card's name / meaning in the
/// active system language.
///
/// Both widgets read the single shared [TranslationService] from
/// the provider tree (`context.read<TranslationService>()`) and
/// watch the active language (`SettingsProvider.language.code`).
/// The [Future] for a card is cached per (card id, target
/// language) and is only re-created when the card id or the
/// active language changes, so unrelated rebuilds never
/// re-translate and never flicker.
///
/// While the translation is loading (or if it is unavailable)
/// the ORIGINAL text is shown, so the widgets never throw and
/// never render blank. When the text could not be translated
/// and its source language differs from the target language, a
/// small dim source-language badge (e.g. " · vi") is appended —
/// language codes only, no new localization keys, no
/// hand-translated strings anywhere in this file.

/// Builds the [Text] for one localized string.
///
/// [original] is shown while loading / on any failure.
/// [textOf] picks the localized string out of [localized].
/// When [localized] is present but untranslated and its source
/// language differs from the target, a dim " · <lang>" badge is
/// appended to the text.
Text _buildLocalizedText({
  required String original,
  required LocalizedCard? localized,
  required String Function(LocalizedCard) textOf,
  TextStyle? style,
  TextAlign? textAlign,
  int? maxLines,
  TextOverflow? overflow,
}) {
  final displayText = localized == null ? original : textOf(localized);
  final showBadge = localized != null &&
      !localized.translated &&
      localized.sourceLang.isNotEmpty &&
      localized.sourceLang != localized.targetLang;
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
          text: ' · ${localized.sourceLang}',
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

/// A card's name in the active system language.
///
/// Shows the original name while the translation loads (or if
/// it is unavailable), and appends a dim source-language badge
/// when the name could not be translated.
class LocalizedCardName extends StatefulWidget {
  const LocalizedCardName({super.key, required this.card, this.style, this.textAlign, this.maxLines, this.overflow});
  final TarotCardModel card; final TextStyle? style; final TextAlign? textAlign; final int? maxLines; final TextOverflow? overflow;

  @override
  State<LocalizedCardName> createState() => _LocalizedCardNameState();
}

class _LocalizedCardNameState extends State<LocalizedCardName> {
  Future<LocalizedCard>? _future;
  int? _cardId;
  String? _targetLang;

  @override
  Widget build(BuildContext context) {
    final targetLang = context.watch<SettingsProvider>().language.code;
    if (_future == null ||
        _cardId != widget.card.id ||
        _targetLang != targetLang) {
      _cardId = widget.card.id;
      _targetLang = targetLang;
      try {
        _future = context
            .read<TranslationService>()
            .localizeCard(widget.card, targetLang: targetLang);
      } catch (_) {
        // No shared service available: fall through and render
        // the original text below; never throw, never blank.
        _future = null;
      }
    }
    return FutureBuilder<LocalizedCard>(
      future: _future,
      builder: (context, snapshot) {
        return _buildLocalizedText(
          original: widget.card.name,
          localized: snapshot.data,
          textOf: (localized) => localized.name,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );
      },
    );
  }
}

/// A card's meaning in the active system language.
///
/// Shows the original meaning while the translation loads (or
/// if it is unavailable), and appends a dim source-language
/// badge when the meaning could not be translated.
class LocalizedCardMeaning extends StatefulWidget {
  const LocalizedCardMeaning({super.key, required this.card, this.style, this.textAlign, this.maxLines, this.overflow});
  final TarotCardModel card; final TextStyle? style; final TextAlign? textAlign; final int? maxLines; final TextOverflow? overflow;

  @override
  State<LocalizedCardMeaning> createState() => _LocalizedCardMeaningState();
}

class _LocalizedCardMeaningState extends State<LocalizedCardMeaning> {
  Future<LocalizedCard>? _future;
  int? _cardId;
  String? _targetLang;

  @override
  Widget build(BuildContext context) {
    final targetLang = context.watch<SettingsProvider>().language.code;
    if (_future == null ||
        _cardId != widget.card.id ||
        _targetLang != targetLang) {
      _cardId = widget.card.id;
      _targetLang = targetLang;
      try {
        _future = context
            .read<TranslationService>()
            .localizeCard(widget.card, targetLang: targetLang);
      } catch (_) {
        // No shared service available: fall through and render
        // the original text below; never throw, never blank.
        _future = null;
      }
    }
    return FutureBuilder<LocalizedCard>(
      future: _future,
      builder: (context, snapshot) {
        return _buildLocalizedText(
          original: widget.card.meaning,
          localized: snapshot.data,
          textOf: (localized) => localized.meaning,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );
      },
    );
  }
}
