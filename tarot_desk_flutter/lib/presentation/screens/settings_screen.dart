import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization.dart';
import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../data/datasources/cloud_sync_service.dart';
import '../../data/datasources/tarotdesk_api_service.dart';
import '../../data/models/user_preferences.dart';
import '../../logic/auth_provider.dart';
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
  Widget _optionChips({
    required AppThemeData theme,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return ChoiceChip(
          label: Text(opt,
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
                onSelected: (_) => settings.setLanguage(lang),
              );
            }).toList(),
          ),
        ],
      ),
    );
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
                label: Text(t.nameVi,
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
              label: Text(item,
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

/// Sync + logout buttons inside the Google account section.
/// A separate StatefulWidget so the syncing state lives here
/// without turning SettingsScreen into a StatefulWidget.
class _AccountActions extends StatefulWidget {
  const _AccountActions({required this.settings, required this.theme});

  final SettingsProvider settings;
  final AppThemeData theme;

  @override
  State<_AccountActions> createState() => _AccountActionsState();
}

class _AccountActionsState extends State<_AccountActions> {
  bool _isSyncing = false;

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    final auth = context.read<AuthProvider>();
    if (auth.sessionToken == null || auth.sessionToken!.isEmpty) {
      // Guests cannot sync: readable error, no crash.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.settings.tr('settings.loginRequired'))),
      );
      return;
    }
    setState(() => _isSyncing = true);
    try {
      await CloudSyncService(auth, targetLanguageCode: () => widget.settings.language.code).uploadFromLocal();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.settings.tr('settings.syncSuccess'))),
      );
    } on TarotdeskApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${widget.settings.tr('settings.syncFailed')} ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.settings.tr('settings.logoutTitle')),
        content: Text(widget.settings.tr('settings.logoutBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(widget.settings.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              widget.settings.tr('settings.logout'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
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
                Text(widget.settings.tr('settings.linkGoogleAccount')),
            onPressed: () =>
                context.read<AuthProvider>().startGoogleLogin(),
          ),
        if (!isGuest)
          ElevatedButton.icon(
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload, size: 18),
            label: Text(widget.settings.tr('settings.syncNow')),
            onPressed: _isSyncing ? null : _syncNow,
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _confirmLogout,
          child: Text(
            widget.settings.tr('settings.logout'),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
