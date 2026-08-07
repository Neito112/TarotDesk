import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';

/// Màn hình Cài đặt giao diện, Theme, Bàn bói bài & Đồ trang trí (Cập nhật bật/tắt 3 lớp)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;

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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Chọn Theme
              GlassPanel(
                backgroundColor: theme.cardBackgroundColor,
                borderColor: theme.glassBorderColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎨 Chọn Chủ Đề Giao Diện (Theme)',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...AppThemeData.availableThemes.values.map((t) {
                      final isSelected = settings.userPrefs.themeId == t.id;
                      return RadioListTile<String>(
                        activeColor: theme.primaryColor,
                        title: Text(
                          t.nameVi,
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                    }).toList(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Cấu hình Bàn Trải Bài Tarot
              GlassPanel(
                backgroundColor: theme.cardBackgroundColor,
                borderColor: theme.glassBorderColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔮 Cấu Hình Bàn Trải Bài Tarot',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Chọn Mẫu Bàn
                    Text('Chất liệu mặt bàn:', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      dropdownColor: theme.cardBackgroundColor,
                      value: settings.userPrefs.tableStyle,
                      items: ['Gỗ Sồi', 'Đá Cổ', 'Vũ Trụ'].map((style) {
                        return DropdownMenuItem<String>(
                          value: style,
                          child: Text(style, style: TextStyle(color: theme.textColor)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) settings.setTableStyle(val);
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.glassBorderColor)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Chọn Khăn Trải
                    Text('Khăn trải bàn:', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      dropdownColor: theme.cardBackgroundColor,
                      value: settings.userPrefs.clothStyle,
                      items: ['Nhung Tím', 'Lụa Vàng', 'Thảm Đen'].map((style) {
                        return DropdownMenuItem<String>(
                          value: style,
                          child: Text(style, style: TextStyle(color: theme.textColor)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) settings.setClothStyle(val);
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.glassBorderColor)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Chọn Đồ Trang Trí (Tối đa 3 món)
                    Text('Đồ trang trí (Chọn tối đa 3 món):', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: ['Đá Thạch Anh', 'Quả Cầu', 'Hương Trầm', 'Lá Khô'].map((item) {
                        final isSelected = settings.userPrefs.decorItems.contains(item);
                        return FilterChip(
                          selectedColor: theme.primaryColor.withOpacity(0.3),
                          checkmarkColor: theme.primaryColor,
                          label: Text(item, style: TextStyle(color: isSelected ? theme.primaryColor : theme.textColor, fontSize: 12)),
                          selected: isSelected,
                          onSelected: (selected) {
                            final current = List<String>.from(settings.userPrefs.decorItems);
                            if (selected) {
                              if (current.length < 3) {
                                current.add(item);
                                settings.setDecorItems(current);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Chỉ được chọn tối đa 3 món trang trí!'), duration: Duration(seconds: 1)),
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
              ),

              const SizedBox(height: 16),

              // 3. Quản lý bật/tắt các lớp nền bói (Mặt bàn, Khăn trải, Đồ decor)
              GlassPanel(
                backgroundColor: theme.cardBackgroundColor,
                borderColor: theme.glassBorderColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🌟 Bật/Tắt Các Lớp Nền Bàn Bói',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      activeColor: theme.primaryColor,
                      title: Text('Hiển thị lớp Mặt Bàn', style: TextStyle(color: theme.textColor)),
                      subtitle: Text('Bật/Tắt lớp nền chất liệu bàn bên dưới', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
                      value: settings.userPrefs.showTable,
                      onChanged: (val) => settings.toggleTable(val),
                    ),
                    const Divider(color: Colors.white12),
                    SwitchListTile(
                      activeColor: theme.primaryColor,
                      title: Text('Hiển thị lớp Khăn Trải Bàn', style: TextStyle(color: theme.textColor)),
                      subtitle: Text('Bật/Tắt tấm khăn thảm đặt trên bàn bói', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
                      value: settings.userPrefs.showCloth,
                      onChanged: (val) => settings.toggleCloth(val),
                    ),
                    const Divider(color: Colors.white12),
                    SwitchListTile(
                      activeColor: theme.primaryColor,
                      title: Text('Hiển thị lớp Đồ Decor', style: TextStyle(color: theme.textColor)),
                      subtitle: Text('Bật/Tắt các vật phẩm thạch anh, quả cầu, trầm hương', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
                      value: settings.userPrefs.showDecor,
                      onChanged: (val) => settings.toggleDecor(val),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
