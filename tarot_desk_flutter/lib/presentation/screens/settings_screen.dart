import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_preferences.dart';
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
          _sectionTitle(theme, 'Chọn Chủ Đề Giao Diện (Theme)'),
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
          _sectionTitle(theme, 'Hiệu Ứng Giao Diện'),
          const SizedBox(height: 4),
          _toggleTile(
            theme: theme,
            title: 'Hiệu ứng kính mờ (Glassmorphism)',
            subtitle: 'Bật/Tắt lớp kính mờ trên các panel',
            value: settings.userPrefs.enableGlassmorphism,
            onChanged: (val) => settings.toggleGlassmorphism(val),
          ),
          _toggleTile(
            theme: theme,
            title: 'Hiệu ứng khói sương',
            subtitle: 'Bật/Tắt các hạt khói bay trên nền',
            value: settings.userPrefs.enableSmokeParticles,
            onChanged: (val) => settings.toggleSmokeParticles(val),
          ),
          _toggleTile(
            theme: theme,
            title: 'Chữ tiêu đề nhấp nháy',
            subtitle: 'Bật/Tắt hiệu ứng nhấp nháy của tiêu đề',
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

    final tableAndCloth = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fieldLabel(theme, 'Chất liệu mặt bàn:'),
        const SizedBox(height: 6),
        _optionChips(
          theme: theme,
          options: UserPreferencesModel.tableStyles,
          selected: settings.userPrefs.tableStyle,
          onSelected: (val) => settings.setTableStyle(val),
        ),
        const SizedBox(height: 4),
        _hintText(theme,
            'Áp dụng trên điện thoại / máy tính bảng. Bản PC dùng tranh bàn gỗ trống, chất liệu không đổi nền PC.'),
        const SizedBox(height: 14),
        _fieldLabel(theme, 'Khăn trải bàn:'),
        const SizedBox(height: 6),
        _optionChips(
          theme: theme,
          options: UserPreferencesModel.clothStyles,
          selected: settings.userPrefs.clothStyle,
          onSelected: (val) => settings.setClothStyle(val),
        ),
        const SizedBox(height: 4),
        _hintText(theme,
            'Đổi ngay trên bàn: khăn là lớp riêng to và phẳng trên mặt gỗ, chuyển màu mượt.'),
      ],
    );

    final decorAndLayers = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fieldLabel(theme,
            'Đồ trang trí (Chọn tối đa ${UserPreferencesModel.maxDecorItems} món):'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: UserPreferencesModel.decorOptions.map((item) {
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
                final current =
                    List<String>.from(settings.userPrefs.decorItems);
                if (selected) {
                  if (current.length <
                      UserPreferencesModel.maxDecorItems) {
                    current.add(item);
                    settings.setDecorItems(current);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Chỉ được chọn tối đa 3 món trang trí!'),
                          duration: Duration(seconds: 1)),
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
        _fieldLabel(theme, 'Hiển thị các lớp trên bàn:'),
        const SizedBox(height: 2),
        _toggleTile(
          theme: theme,
          title: 'Hiển thị lớp Mặt Bàn',
          subtitle: 'Bật/Tắt lớp nền chất liệu bàn bên dưới',
          value: settings.userPrefs.showTable,
          onChanged: (val) => settings.toggleTable(val),
        ),
        _toggleTile(
          theme: theme,
          title: 'Hiển thị lớp Khăn Trải Bàn',
          subtitle: 'Bật/Tắt tấm khăn phẳng đặt trên bàn bói',
          value: settings.userPrefs.showCloth,
          onChanged: (val) => settings.toggleCloth(val),
        ),
        _toggleTile(
          theme: theme,
          title: 'Hiển thị lớp Đồ Decor',
          subtitle:
              'Bật/Tắt các vật phẩm thạch anh, quả cầu, trầm hương',
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
          _sectionTitle(theme, 'Cấu Hình Bàn Trải Bài Tarot'),
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
    final theme = settings.currentThemeData;
    final isWide = Responsive.isTablet(context) ||
        Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: Responsive.isDesktop(context) ? 48 : null,
        title: Text('Cài Đặt Giao Diện',
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
