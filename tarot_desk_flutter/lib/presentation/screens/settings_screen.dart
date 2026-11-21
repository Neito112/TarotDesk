import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/display_labels.dart';
import '../../core/localization.dart';
import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/translation_service.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/datasources/tarotdesk_api_service.dart';
import '../../data/models/tarot_card.dart';
import '../../data/models/user_preferences.dart';
import '../../logic/auth_provider.dart';
import '../../logic/deck_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';

/// Màn hình Cài đặt giao diện, Theme, Bàn bói bài & Đồ trang trí.
/// Bố cục: mobile-first Android (1 cột), iPad/PC (Theme + Hiệu ứng
/// cạnh nhau, bàn trải bài hai cột: bàn+khăn / decor+lớp).
/// Mọi lựa chọn dùng chip nhìn (theme, bàn, khăn, decor) cho gọn
/// và quét nhanh; toggle gọn (dense). PC: nội dung căn giữa, rộng
/// tối đa 1080.
///
/// Mọi trường trong [UserPreferencesModel] đều có control ở đây và
/// đều được ít nhất một màn hình đọc — không còn toggle "mồ côi".
/// Tất cả cấu hình bàn (chất liệu, khăn, decor, bật/tắt
/// các lớp) nằm trong MỘT mục "Cấu Hình Bàn Trải Bài Tarot".
/// Các danh sách lựa chọn dùng chung hằng số trong
/// [UserPreferencesModel] (tableStyles / clothStyles / decorOptions)
/// để không lệch với dialog đổi bàn trong màn Trải bài.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  static const double _sectionGap = 16;

  Widget _sectionTitle(AppThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        color: theme.primaryColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _fieldLabel(AppThemeData theme, String label) {
    return Text(label,
        style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 13));
  }

  Widget _hintText(AppThemeData theme, String text) {
    return Text(
      text,
      style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
    );
  }

  Widget _toggleTile({
    required AppThemeData theme,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      activeColor: theme.primaryColor,
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(title, style: TextStyle(color: theme.textColor, fontSize: 13)),
      subtitle: Text(subtitle,
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 11)),
      value: value,
      onChanged: onChanged,
    );
  }

  /// Chip chọn một giá trị (bàn / khăn): gọn, quét nhanh, cùng
  /// ngôn ngữ với chip decor và chip theme.
  /// [labelFor] maps the stored option id to its DISPLAY label
  /// (already translated) — selection and callbacks still use the
  /// raw stored id, which never changes.
  Widget _optionChips({
    required AppThemeData theme,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    required String Function(String) labelFor,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return ChoiceChip(
          label: Text(labelFor(opt),
              style: TextStyle(
                  color: isSelected ? Colors.black : theme.textColor,
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal)),
          selected: isSelected,
          selectedColor: theme.primaryColor,
          backgroundColor: Colors.white10,
          side: BorderSide(
              color: isSelected
                  ? theme.primaryColor
                  : theme.glassBorderColor),
          visualDensity: VisualDensity.compact,
          onSelected: (_) => onSelected(opt),
        );
      }).toList(),
    );
  }

  /// Chọn ngôn ngữ giao diện bằng chip: mỗi chip hiện tên ngôn ngữ
  /// bằng chính ngôn ngữ đó, ngôn ngữ đang chọn được tô nổi.
  Widget _languageSection(
      BuildContext context, SettingsProvider settings, AppThemeData theme) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, settings.tr('settings.language')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: AppLanguage.values.map((lang) {
              final isSelected = settings.language == lang;
              return ChoiceChip(
                label: Text(lang.label,
                    style: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : theme.textColor,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal)),
                selected: isSelected,
                selectedColor: theme.primaryColor,
                backgroundColor: Colors.white10,
                side: BorderSide(
                    color: isSelected
                        ? theme.primaryColor
                        : theme.glassBorderColor),
                visualDensity: VisualDensity.compact,
                onSelected: (_) => _switchLanguageWithLoading(context, lang),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Chặn chạm đúp: một lần đổi ngôn ngữ đang chạy thì chạm thêm
  /// chip khác không làm gì (dialog đang chặn tương tác nên gần
  /// như không chạm được, nhưng vẫn chặn cho chắc).
  static bool _isSwitchingLanguage = false;

  /// Đổi ngôn ngữ kèm màn hình chờ: dịch HẾT nội dung các lá bài
  /// sang ngôn ngữ mới TRƯỚC, rồi mới chuyển ngôn ngữ.
  ///
  /// Hiện dialog loading chặn tương tác (không đóng được bằng nút
  /// back hay chạm ngoài), dịch toàn bộ tên + ý nghĩa của mọi lá
  /// trong mọi bộ bài local qua Worker (theo lô 20 chuỗi, dùng
  /// lại [TranslationService.warmCache]), cập nhật tiến độ theo
  /// từng lô, rồi mới gọi [SettingsProvider.setLanguage] và đóng
  /// dialog. Nhờ đó sau khi đổi ngôn ngữ, nội dung các lá đã
  /// dịch sẵn — không còn hiện tiếng Việt trước rồi mới chuyển
  /// sang tiếng mới, không chờ từng lá khi mở ra.
  ///
  /// Chạm vào ngôn ngữ đang dùng thì không làm gì. Lô nào lỗi
  /// (Worker chậm / mất mạng) thì bỏ qua lô đó — các lá đó sẽ
  /// dịch khi mở ra sau (on demand) — và ngôn ngữ vẫn được đổi.
  /// Dialog luôn đóng và ngôn ngữ luôn đổi, kể cả khi dịch lỗi.
  Future<void> _switchLanguageWithLoading(
    BuildContext context,
    AppLanguage targetLang,
  ) async {
    final settings = context.read<SettingsProvider>();
    if (settings.language == targetLang) return;
    if (_isSwitchingLanguage) return;
    _isSwitchingLanguage = true;
    try {
      final deckProvider = context.read<DeckProvider>();
      final translation = context.read<TranslationService>();

      // Thu thập toàn bộ lá bài của mọi bộ bài local để biết
      // tổng số lá (cho thanh tiến độ) trước khi hiện dialog.
      // Đọc từ DB local nên nhanh; không dịch gì ở bước này.
      final deckNames = <String>[];
      final deckIds = <int?>[];
      final deckCardsList = <List<TarotCardModel>>[];
      var totalCards = 0;
      for (final deck in deckProvider.decks) {
        if (deck.id == null) continue;
        final cards =
            await DatabaseHelper.instance.getCardsByDeckId(deck.id!);
        if (cards.isEmpty) continue;
        deckNames.add(deck.name);
        deckIds.add(deck.id);
        deckCardsList.add(cards);
        totalCards += cards.length;
      }

      // Không có lá nào để dịch: đổi ngôn ngữ ngay, không cần dialog.
      if (totalCards == 0) {
        settings.setLanguage(targetLang);
        return;
      }

      // Tiến độ cho dialog: số lá đã xử lý (dịch xong hoặc bỏ qua).
      final doneCards = ValueNotifier<int>(0);
      // Text trong dialog dùng ngôn ngữ HIỆN TẠI (chưa đổi).
      final title = settings.tr('settings.translatingTitle');
      final bodyTemplate = settings.tr('settings.translatingBody');

      // Hiện dialog loading chặn tương tác. Không await — dialog
      // chạy song song với quá trình dịch; đóng lại ở cuối.
      var dialogOpen = true;
      final dialogFuture = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(title),
              content: ValueListenableBuilder<int>(
                valueListenable: doneCards,
                builder: (context, done, _) {
                  final body = bodyTemplate
                      .replaceAll('{language}', targetLang.label)
                      .replaceAll('{done}', '$done')
                      .replaceAll('{total}', '$totalCards');
                  final progress =
                      totalCards > 0 ? done / totalCards : 0.0;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(body),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
      // Dọn progress notifier khi dialog đã đóng hẳn.
      unawaited(dialogFuture.then((_) => doneCards.dispose()));

      try {
        // WIRING (V2 display path): nạp TRƯỚC bản dịch vĩnh viễn
        // đã lưu của mọi bộ bài sang ngôn ngữ mới (một lần tra
        // cứu D1 nhanh cho mỗi bộ, chạy song song). warmCache ở
        // dưới sẽ BỎ QUA các chuỗi đã có trong bộ nhớ đệm, nên
        // bộ bài đã dịch trước không tốn gọi MT và bản dịch đã
        // lưu không bị ghi đè. Bộ nào chưa có bản dịch lưu sẵn
        // thì preload trả 0 và warmCache dịch như trước. Không
        // bao giờ ném lỗi (mỗi preload có timeout ngắn riêng);
        // khách chưa đăng nhập vẫn nạp được bộ bài cơ bản (dữ
        // liệu chung, công khai), còn bộ riêng của họ thì không
        // có danh tính server nên preload trả 0.
        await Future.wait(<Future<int>>[
          for (var d = 0; d < deckCardsList.length; d++)
            translation.preloadLocalDeck(
              deckId: deckIds[d],
              deckName: deckNames[d],
              cards: deckCardsList[d],
              lang: targetLang.code,
            ),
        ]);
        // Dịch từng bộ bài (theo lô 20 chuỗi), cộng dồn tiến độ.
        // targetLang được truyền rõ ràng — KHÔNG dựa vào ngôn ngữ
        // trong SettingsProvider vì nó chưa đổi lúc này.
        var doneBefore = 0;
        for (var d = 0; d < deckCardsList.length; d++) {
          final cards = deckCardsList[d];
          await translation.warmCache(
            cards,
            deckName: deckNames[d],
            targetLang: targetLang.code,
            onProgress: (doneStrings, _) {
              // Mỗi lá = 2 chuỗi (tên + ý nghĩa), lô 20 chuỗi
              // luôn khớp ranh giới lá nên chia 2 là chính xác.
              doneCards.value = doneBefore + (doneStrings ~/ 2);
            },
          );
          doneBefore += cards.length;
          // Đảm bảo tiến độ không kẹt nếu warmCache về sớm.
          doneCards.value = doneBefore;
        }
      } finally {
        // Dù dịch xong hay lỗi, vẫn đổi ngôn ngữ rồi đóng dialog.
        settings.setLanguage(targetLang);
        if (dialogOpen) {
          dialogOpen = false;
          if (context.mounted) Navigator.of(context).pop();
        }
      }
    } finally {
      _isSwitchingLanguage = false;
    }
  }

  /// Google account section: the signed-in Google account, sync data
  /// to the cloud, and log out. Local data is NOT deleted on logout.
  /// Guests see a generic icon and a guest label instead of an account.
  Widget _accountSection(BuildContext context, SettingsProvider settings,
      AppThemeData theme, AuthProvider auth) {
    final user = auth.user;
    final isGuest = auth.isGuest || user == null;
    final pictureUrl = isGuest ? null : user.picture;
    final displayName = isGuest
        ? settings.tr('settings.guestAccount')
        : (user.name.isNotEmpty ? user.name : user.email);
    final email = isGuest ? null : user.email;
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, settings.tr('settings.accountTitle')),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                backgroundImage: pictureUrl != null && pictureUrl.isNotEmpty
                    ? NetworkImage(pictureUrl)
                    : null,
                child: pictureUrl == null || pictureUrl.isEmpty
                    ? const Icon(Icons.account_circle)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.tr('settings.accountLabel'),
                      style: TextStyle(
                          color: theme.secondaryTextColor, fontSize: 11),
                    ),
                    Text(
                      displayName,
                      style: TextStyle(
                          color: theme.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    if (email != null && email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                            color: theme.secondaryTextColor, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AccountActions(settings: settings, theme: theme),
        ],
      ),
    );
  }

  /// Chọn theme bằng chip nhìn (không còn danh sách radio dọc dài):
  /// gọn, quét nhanh, cùng ngôn ngữ chip với phần bàn/khăn/decor.
  Widget _themeSection(BuildContext context, SettingsProvider settings,
      AppThemeData theme) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, settings.tr('settings.themeTitle')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: AppThemeData.availableThemes.values.map((t) {
              final isSelected = settings.userPrefs.themeId == t.id;
              return ChoiceChip(
                label: Text(settings.tr(themeDisplayKey(t.id)),
                    style: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : theme.textColor,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal)),
                selected: isSelected,
                selectedColor: theme.primaryColor,
                backgroundColor: Colors.white10,
                side: BorderSide(
                    color: isSelected
                        ? theme.primaryColor
                        : theme.glassBorderColor),
                visualDensity: VisualDensity.compact,
                onSelected: (_) => settings.setTheme(t.id),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _effectsSection(
      SettingsProvider settings, AppThemeData theme) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, settings.tr('settings.effectsTitle')),
          const SizedBox(height: 4),
          _toggleTile(
            theme: theme,
            title: settings.tr('settings.glassTitle'),
            subtitle: settings.tr('settings.glassSubtitle'),
            value: settings.userPrefs.enableGlassmorphism,
            onChanged: (val) => settings.toggleGlassmorphism(val),
          ),
          _toggleTile(
            theme: theme,
            title: settings.tr('settings.smokeTitle'),
            subtitle: settings.tr('settings.smokeSubtitle'),
            value: settings.userPrefs.enableSmokeParticles,
            onChanged: (val) => settings.toggleSmokeParticles(val),
          ),
          _toggleTile(
            theme: theme,
            title: settings.tr('settings.twinkleTitle'),
            subtitle: settings.tr('settings.twinkleSubtitle'),
            value: settings.userPrefs.enableTwinklingText,
            onChanged: (val) => settings.toggleTwinklingText(val),
          ),
        ],
      ),
    );
  }

  /// MỘT mục duy nhất cho toàn bộ bàn trải bài: chất liệu mặt bàn,
  /// khăn trải bàn, đồ trang trí, và bật/tắt 3 lớp
  /// (mặt bàn / khăn / decor). Mọi control ở đây đều gọi setter
  /// của SettingsProvider nên màn Trải bài cập nhật ngay khi đổi.
  /// Bố cục lại: bàn + khăn chọn bằng chip nhìn (không còn
  /// dropdown), màn rộng thì hai cột (trái: bàn + khăn, phải:
  /// decor + lớp hiển thị), điện thoại một cột.
  Widget _tableSection(
      BuildContext context, SettingsProvider settings, AppThemeData theme) {
    final isWide = Responsive.isTablet(context) ||
        Responsive.isDesktop(context);

    // Chỉ kiểu bàn có tranh vẽ mới là lựa chọn thật (hiện chỉ 'Gỗ Sồi';
    // 'Đá Cổ' / 'Vũ Trụ' chưa có tranh bàn vẽ nên không hiện — cùng
    // cách lọc như dialog đổi bàn trong new_reading_screen.dart).
    // Nếu kiểu đã lưu không có tranh vẽ, hiển thị 'Gỗ Sồi' là đã chọn
    // (đó mới là mặt bàn thật đang vẽ).
    final effectiveTableStyle =
        settings.userPrefs.tableStyle == 'Gỗ Sồi'
            ? settings.userPrefs.tableStyle
            : 'Gỗ Sồi';

    final tableAndCloth = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fieldLabel(theme, settings.tr('settings.tableMaterialLabel')),
        const SizedBox(height: 6),
        _optionChips(
          theme: theme,
          options: UserPreferencesModel.tableStyles
              .where((s) => s == 'Gỗ Sồi')
              .toList(),
          selected: effectiveTableStyle,
          onSelected: (val) => settings.setTableStyle(val),
          labelFor: (opt) => settings.tr(tableStyleDisplayKey(opt)),
        ),
        const SizedBox(height: 4),
        _hintText(theme, settings.tr('settings.tableHint')),
        const SizedBox(height: 14),
        _fieldLabel(theme, settings.tr('settings.clothLabel')),
        const SizedBox(height: 6),
        _optionChips(
          theme: theme,
          options: UserPreferencesModel.clothStyles,
          selected: settings.userPrefs.clothStyle,
          onSelected: (val) => settings.setClothStyle(val),
          labelFor: (opt) => settings.tr(clothDisplayKey(opt)),
        ),
        const SizedBox(height: 4),
        _hintText(theme, settings.tr('settings.clothHint')),
      ],
    );

    final decorAndLayers = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fieldLabel(
            theme,
            settings.tr('settings.decorLabel').replaceAll(
                '{n}', '${UserPreferencesModel.maxDecorItems}')),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          // Chỉ món có ảnh cắt vẽ thật mới hiện làm lựa chọn
          // ('Lá Khô' chưa có ảnh cắt nên không có ở đây — cùng
          // cách lọc như dialog đổi bàn trong new_reading_screen.dart).
          children: UserPreferencesModel.decorOptions
              .where((item) => item != 'Lá Khô')
              .map((item) {
            final isSelected =
                settings.userPrefs.decorItems.contains(item);
            return FilterChip(
              selectedColor: theme.primaryColor.withOpacity(0.3),
              checkmarkColor: theme.primaryColor,
              label: Text(settings.tr(decorDisplayKey(item)),
                  style: TextStyle(
                      color: isSelected
                          ? theme.primaryColor
                          : theme.textColor,
                      fontSize: 12)),
              selected: isSelected,
              visualDensity: VisualDensity.compact,
              onSelected: (selected) {
                // Bỏ món không có ảnh vẽ ra khỏi danh sách đã lưu
                // TRƯỚC khi đếm: 'Lá Khô' đã chọn từ bản cũ không
                // hiện trong Cài đặt và không vẽ trên bàn, nhưng vẫn
                // chiếm 1 trong 3 suất nếu còn sót trong decorItems.
                final current = settings.userPrefs.decorItems
                    .where((i) => i != 'Lá Khô')
                    .toList();
                if (selected) {
                  if (current.length <
                      UserPreferencesModel.maxDecorItems) {
                    current.add(item);
                    settings.setDecorItems(current);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(settings
                              .tr('settings.decorLimit')
                              .replaceAll('{n}',
                                  '${UserPreferencesModel.maxDecorItems}')),
                          duration: const Duration(seconds: 1)),
                    );
                  }
                } else {
                  current.remove(item);
                  settings.setDecorItems(current);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _fieldLabel(theme, settings.tr('settings.layersLabel')),
        const SizedBox(height: 2),
        _toggleTile(
          theme: theme,
          title: settings.tr('settings.showTableTitle'),
          subtitle: settings.tr('settings.showTableSubtitle'),
          value: settings.userPrefs.showTable,
          onChanged: (val) => settings.toggleTable(val),
        ),
        _toggleTile(
          theme: theme,
          title: settings.tr('settings.showClothTitle'),
          subtitle: settings.tr('settings.showClothSubtitle'),
          value: settings.userPrefs.showCloth,
          onChanged: (val) => settings.toggleCloth(val),
        ),
        _toggleTile(
          theme: theme,
          title: settings.tr('settings.showDecorTitle'),
          subtitle: settings.tr('settings.showDecorSubtitle'),
          value: settings.userPrefs.showDecor,
          onChanged: (val) => settings.toggleDecor(val),
        ),
      ],
    );

    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, settings.tr('settings.tableTitle')),
          const SizedBox(height: 12),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tableAndCloth),
                const SizedBox(width: 20),
                Expanded(child: decorAndLayers),
              ],
            )
          else ...[
            tableAndCloth,
            const SizedBox(height: 16),
            decorAndLayers,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = settings.currentThemeData;
    final isWide = Responsive.isTablet(context) ||
        Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: Responsive.isDesktop(context) ? 48 : null,
        title: Text(settings.tr('settings.title'),
            style: TextStyle(
                fontSize: Responsive.isDesktop(context) ? 16 : 20)),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _languageSection(context, settings, theme),
                const SizedBox(height: _sectionGap),
                _accountSection(context, settings, theme, auth),
                const SizedBox(height: _sectionGap),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _themeSection(context, settings, theme)),
                      const SizedBox(width: _sectionGap),
                      Expanded(child: _effectsSection(settings, theme)),
                    ],
                  )
                else ...[
                  _themeSection(context, settings, theme),
                  const SizedBox(height: _sectionGap),
                  _effectsSection(settings, theme),
                ],
                const SizedBox(height: _sectionGap),
                _tableSection(context, settings, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logout (+ guest link) buttons inside the Google account section.
///
/// Sync is automatic now (on login and on page reload), so there is
/// no manual sync button and no syncing state here — this is a plain
/// StatelessWidget. The guest "link Google account" button and the
/// logout button are the only actions left.
class _AccountActions extends StatelessWidget {
  const _AccountActions({required this.settings, required this.theme});

  final SettingsProvider settings;
  final AppThemeData theme;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(settings.tr('settings.logoutTitle')),
        content: Text(settings.tr('settings.logoutBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(settings.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              settings.tr('settings.logout'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (!context.mounted) return;
      // Settings was pushed on top of Home; after logout the gate
      // rebuilds to the login screen, but this pushed route would
      // still cover it. Pop back to the first route so the login
      // screen is actually visible.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = context.watch<AuthProvider>().isGuest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isGuest)
          ElevatedButton.icon(
            icon: const Icon(Icons.link, size: 18),
            label:
                Text(settings.tr('settings.linkGoogleAccount')),
            onPressed: () =>
                context.read<AuthProvider>().startGoogleLogin(),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _confirmLogout(context),
          child: Text(
            settings.tr('settings.logout'),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
