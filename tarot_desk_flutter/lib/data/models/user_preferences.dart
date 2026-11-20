/// Model lưu các cài đặt giao diện của người dùng.
///
/// Mọi trường ở đây đều có control tương ứng trong SettingsScreen và
/// đều được ít nhất một màn hình đọc (xem SettingsProvider).
/// Các trường kiểu "lựa chọn" chỉ nhận giá trị trong danh sách cho
/// phép: [fromMap] lọc mọi giá trị lạ từ dữ liệu cũ về mặc định an
/// toàn, vì Dropdown trong Cài đặt sẽ crash nếu nhận value ngoài
/// danh sách items. Các trường bool chấp nhận cả bool / số 1-0 /
/// chuỗi khi đọc dữ liệu cũ.
///
/// Đã bỏ trường `customBackgroundImagePath`: nó được lưu nhưng không
/// màn hình nào đọc và không có control nào trong Cài đặt để đặt nó
/// (xem báo cáo track 5). Dữ liệu cũ còn key `custom_bg_path` vẫn
/// load bình thường — [fromMap] chỉ bỏ qua key lạ.
class UserPreferencesModel {
  /// Các lựa chọn hợp lệ cho từng trường kiểu enum-chuỗi.
  /// Giữ đồng bộ với các dropdown/chip trong SettingsScreen và
  /// dialog đổi bàn trong NewReadingScreen — hai nơi này dùng
  /// chính các danh sách này, không hard-code riêng.
  static const List<String> tableStyles = ['Gỗ Sồi', 'Đá Cổ', 'Vũ Trụ'];
  static const List<String> clothStyles = ['Nhung Tím', 'Lụa Vàng', 'Thảm Đen'];
  static const List<String> decorOptions = [
    'Đá Thạch Anh',
    'Quả Cầu',
    'Hương Trầm',
    'Nến Đen',
    'Lá Khô'
  ];
  static const int maxDecorItems = 3;

  /// Phải khớp AppThemeData.availableThemes. Không import theme vào
  /// model để tầng data không phụ thuộc tầng UI.
  static const List<String> themeIds = [
    'default_dark',
    'mystical_purple',
    'golden_sun',
    'gothic_night'
  ];

  /// Mặc định khi chưa có dữ liệu lưu (key thiếu) — dùng chung cho
  /// cả fromMap và trường hợp người dùng bỏ chọn hết decor.
  static const List<String> defaultDecorItems = [
    'Đá Thạch Anh',
    'Quả Cầu',
    'Hương Trầm'
  ];

  String themeId;
  bool enableGlassmorphism;
  bool enableSmokeParticles;
  bool enableTwinklingText;

  // Cấu hình hiển thị và Bàn Trải Bài Tarot
  bool showTable; // Bật/tắt lớp mặt bàn
  bool showCloth; // Bật/tắt lớp khăn trải bàn
  bool showDecor; // Bật/tắt lớp đồ decor trang trí
  String tableStyle; // Một trong [tableStyles]
  String clothStyle; // Một trong [clothStyles]
  List<String> decorItems; // Tối đa [maxDecorItems] món trong [decorOptions]
  String spreadMode; // Kiểu trải bài trên bàn: 'single' (1 hàng) hoặc 'multi' (nhiều hàng)

  UserPreferencesModel({
    this.themeId = 'default_dark',
    this.enableGlassmorphism = true,
    this.enableSmokeParticles = true,
    this.enableTwinklingText = true,
    this.showTable = true,
    this.showCloth = true,
    this.showDecor = true,
    this.tableStyle = 'Gỗ Sồi',
    this.clothStyle = 'Nhung Tím',
    this.decorItems = defaultDecorItems,
    this.spreadMode = 'multi',
  });

  Map<String, dynamic> toMap() {
    return {
      'theme_id': themeId,
      'enable_glassmorphism': enableGlassmorphism,
      'enable_smoke': enableSmokeParticles,
      'enable_twinkling': enableTwinklingText,
      'show_table': showTable,
      'show_cloth': showCloth,
      'show_decor': showDecor,
      'table_style': tableStyle,
      'cloth_style': clothStyle,
      'decor_items': decorItems.join(','),
      'spread_mode': spreadMode,
    };
  }

  /// Đọc bool từ dữ liệu cũ ở mọi dạng từng được lưu: bool, số
  /// 1/0 (dạng cũ của show_table/show_cloth/show_decor), chuỗi.
  static bool _boolFrom(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return fallback;
  }

  /// Đọc một lựa chọn: chỉ nhận giá trị trong [allowed], còn lại
  /// (thiếu key, null, giá trị lạ từ bản cũ) về [fallback].
  static String _choiceFrom(
      dynamic value, List<String> allowed, String fallback) {
    final v = value as String?;
    return (v != null && allowed.contains(v)) ? v : fallback;
  }

  /// Đọc danh sách decor: key thiếu/null -> mặc định 3 món;
  /// chuỗi rỗng -> người dùng đã bỏ chọn hết, giữ rỗng;
  /// chỉ giữ món trong [decorOptions], bỏ trùng, tối đa 3 món.
  static List<String> _decorFrom(dynamic value) {
    if (value == null) return List<String>.from(defaultDecorItems);
    final raw = value as String?;
    if (raw == null) return List<String>.from(defaultDecorItems);
    final seen = <String>{};
    final items = <String>[];
    for (final part in raw.split(',')) {
      final item = part.trim();
      if (decorOptions.contains(item) && seen.add(item)) items.add(item);
      if (items.length == maxDecorItems) break;
    }
    return items;
  }

  factory UserPreferencesModel.fromMap(Map<String, dynamic> map) {
    return UserPreferencesModel(
      themeId: _choiceFrom(map['theme_id'], themeIds, 'default_dark'),
      enableGlassmorphism:
          _boolFrom(map['enable_glassmorphism'], true),
      enableSmokeParticles: _boolFrom(map['enable_smoke'], true),
      enableTwinklingText: _boolFrom(map['enable_twinkling'], true),
      showTable: _boolFrom(map['show_table'], true),
      showCloth: _boolFrom(map['show_cloth'], true),
      showDecor: _boolFrom(map['show_decor'], true),
      tableStyle: _choiceFrom(map['table_style'], tableStyles, 'Gỗ Sồi'),
      clothStyle: _choiceFrom(map['cloth_style'], clothStyles, 'Nhung Tím'),
      decorItems: _decorFrom(map['decor_items']),
      // Dữ liệu cũ chưa có key này -> mặc định 'multi' (nhiều hàng).
      spreadMode: (map['spread_mode'] as String? ?? 'multi') == 'single'
          ? 'single'
          : 'multi',
    );
  }
}
