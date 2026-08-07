/// Model lưu các cài đặt giao diện của người dùng
class UserPreferencesModel {
  String themeId;
  String? customBackgroundImagePath;
  bool enableGlassmorphism;
  bool enableSmokeParticles;
  bool enableTwinklingText;
  
  // Cấu hình hiển thị và Bàn Trải Bài Tarot
  bool showTable; // Bật/tắt lớp mặt bàn
  bool showCloth; // Bật/tắt lớp khăn trải bàn
  bool showDecor; // Bật/tắt lớp đồ decor trang trí
  String tableStyle; // e.g. 'Gỗ Sồi', 'Đá Cổ', 'Vũ Trụ'
  String clothStyle; // e.g. 'Nhung Tím', 'Lụa Vàng', 'Thảm Đen'
  List<String> decorItems; // Danh sách tối đa 3 món: 'Đá Thạch Anh', 'Quả Cầu', 'Hương Trầm', 'Lá Khô'

  UserPreferencesModel({
    this.themeId = 'default_dark',
    this.customBackgroundImagePath,
    this.enableGlassmorphism = true,
    this.enableSmokeParticles = true,
    this.enableTwinklingText = true,
    this.showTable = true,
    this.showCloth = true,
    this.showDecor = true,
    this.tableStyle = 'Gỗ Sồi',
    this.clothStyle = 'Nhung Tím',
    this.decorItems = const ['Đá Thạch Anh', 'Quả Cầu', 'Hương Trầm'],
  });

  Map<String, dynamic> toMap() {
    return {
      'theme_id': themeId,
      'custom_bg_path': customBackgroundImagePath,
      'enable_glassmorphism': enableGlassmorphism,
      'enable_smoke': enableSmokeParticles,
      'enable_twinkling': enableTwinklingText,
      'show_table': showTable ? 1 : 0,
      'show_cloth': showCloth ? 1 : 0,
      'show_decor': showDecor ? 1 : 0,
      'table_style': tableStyle,
      'cloth_style': clothStyle,
      'decor_items': decorItems.join(','),
    };
  }

  factory UserPreferencesModel.fromMap(Map<String, dynamic> map) {
    final decorStr = map['decor_items'] as String? ?? 'Đá Thạch Anh,Quả Cầu,Hương Trầm';
    final items = decorStr.isEmpty ? <String>[] : decorStr.split(',');
    return UserPreferencesModel(
      themeId: map['theme_id'] as String? ?? 'default_dark',
      customBackgroundImagePath: map['custom_bg_path'] as String?,
      enableGlassmorphism: map['enable_glassmorphism'] as bool? ?? true,
      enableSmokeParticles: map['enable_smoke'] as bool? ?? true,
      enableTwinklingText: map['enable_twinkling'] as bool? ?? true,
      showTable: map['show_table'] == null ? true : (map['show_table'] == 1),
      showCloth: map['show_cloth'] == null ? true : (map['show_cloth'] == 1),
      showDecor: map['show_decor'] == null ? true : (map['show_decor'] == 1),
      tableStyle: map['table_style'] as String? ?? 'Gỗ Sồi',
      clothStyle: map['cloth_style'] as String? ?? 'Nhung Tím',
      decorItems: items.take(3).toList(), // Tối đa 3 món
    );
  }
}
