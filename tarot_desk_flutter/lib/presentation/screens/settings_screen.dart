import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';

/// Màn hình Cài đặt giao diện, Theme, Bàn bói bài & Đồ trang trí (Cập nhật bật/tắt 3 lớp)
/// Bố cục: mobile-first Android (1 cột), iPad (2 cột cho Theme + Hiệu ứng),
/// PC (nội dung căn giữa, rộng tối đa 1080). Mọi toggle trong SettingsProvider
/// đều có mặt trên màn hình, không còn toggle "mồ côi".
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  static const double _sectionGap = 16;

  InputDecoration _fieldDecoration(AppThemeData theme) {
    return InputDecoration(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.glassBorderColor)),
      focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.primaryColor)),
    );
  }

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
      title: Text(title, style: TextStyle(color: theme.textColor)),
      subtitle: Text(subtitle,
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _themeSection(BuildContext context, SettingsProvider settings,
      AppThemeData theme) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, '🎨 Chọn Chủ Đề Giao Diện (Theme)'),
          const SizedBox(height: 12),
          ...AppThemeData.availableThemes.values.map((t) {
            final isSelected = settings.userPrefs.themeId == t.id;
            return RadioListTile<String>(
              activeColor: theme.primaryColor,
              contentPadding: EdgeInsets.zero,
              title: Text(
                t.nameVi,
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              value: t.id,
              groupValue: settings.userPrefs.themeId,
              onChanged: (val) {
                if (val != null) {
                  settings.setTheme(val);
                }
              },
            );
          }),
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
          _sectionTitle(theme, '✨ Hiệu Ứng Giao Diện'),
          const SizedBox(height: 8),
          _toggleTile(
            theme: theme,
            title: 'Hiệu ứng kính mờ (Glassmorphism)',
            subtitle: 'Bật/Tắt lớp kính mờ trên các panel',
            value: settings.userPrefs.enableGlassmorphism,
            onChanged: (val) => settings.toggleGlassmorphism(val),
          ),
          const Divider(color: Colors.white12),
          _toggleTile(
            theme: theme,
            title: 'Hiệu ứng khói sương',
            subtitle: 'Bật/Tắt các hạt khói bay trên nền',
            value: settings.userPrefs.enableSmokeParticles,
            onChanged: (val) => settings.toggleSmokeParticles(val),
          ),
          const Divider(color: Colors.white12),
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

  Widget _tableSection(
      BuildContext context, SettingsProvider settings, AppThemeData theme) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, '🔮 Cấu Hình Bàn Trải Bài Tarot'),
          const SizedBox(height: 12),
          _fieldLabel(theme, 'Chất liệu mặt bàn:'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            dropdownColor: theme.cardBackgroundColor,
            isExpanded: true,
            value: settings.userPrefs.tableStyle,
            items: ['Gỗ Sồi', 'Đá Cổ', 'Vũ Trụ'].map((style) {
              return DropdownMenuItem<String>(
                value: style,
                child: Text(style,
                    style: TextStyle(color: theme.textColor)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) settings.setTableStyle(val);
            },
            decoration: _fieldDecoration(theme),
          ),
          const SizedBox(height: 16),
          _fieldLabel(theme, 'Khăn trải bàn:'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            dropdownColor: theme.cardBackgroundColor,
            isExpanded: true,
            value: settings.userPrefs.clothStyle,
            items: ['Nhung Tím', 'Lụa Vàng', 'Thảm Đen'].map((style) {
              return DropdownMenuItem<String>(
                value: style,
                child: Text(style,
                    style: TextStyle(color: theme.textColor)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) settings.setClothStyle(val);
            },
            decoration: _fieldDecoration(theme),
          ),
          const SizedBox(height: 16),
          _fieldLabel(theme, 'Đồ trang trí (Chọn tối đa 3 món):'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: ['Đá Thạch Anh', 'Quả Cầu', 'Hương Trầm', 'Lá Khô']
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
                onSelected: (selected) {
                  final current =
                      List<String>.from(settings.userPrefs.decorItems);
                  if (selected) {
                    if (current.length < 3) {
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
        ],
      ),
    );
  }

  Widget _layersSection(SettingsProvider settings, AppThemeData theme) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, '🌟 Bật/Tắt Các Lớp Nền Bàn Bói'),
          const SizedBox(height: 8),
          _toggleTile(
            theme: theme,
            title: 'Hiển thị lớp Mặt Bàn',
            subtitle: 'Bật/Tắt lớp nền chất liệu bàn bên dưới',
            value: settings.userPrefs.showTable,
            onChanged: (val) => settings.toggleTable(val),
          ),
          const Divider(color: Colors.white12),
          _toggleTile(
            theme: theme,
            title: 'Hiển thị lớp Khăn Trải Bàn',
            subtitle: 'Bật/Tắt tấm khăn thảm đặt trên bàn bói',
            value: settings.userPrefs.showCloth,
            onChanged: (val) => settings.toggleCloth(val),
          ),
          const Divider(color: Colors.white12),
          _toggleTile(
            theme: theme,
            title: 'Hiển thị lớp Đồ Decor',
            subtitle:
                'Bật/Tắt các vật phẩm thạch anh, quả cầu, trầm hương',
            value: settings.userPrefs.showDecor,
            onChanged: (val) => settings.toggleDecor(val),
          ),
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
        title: const Text('Cài Đặt Giao Diện'),
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
                const SizedBox(height: _sectionGap),
                _layersSection(settings, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
