import 'package:flutter/material.dart';
import '../core/localization.dart';
import '../core/theme/app_theme.dart';
import '../data/datasources/preferences_service.dart';
import '../data/models/user_preferences.dart';

/// Nguồn duy nhất cho mọi cài đặt của app (single source of truth).
///
/// Quy tắc thống nhất cho mọi setter: validate đầu vào -> ghi vào
/// [_userPrefs] -> [_save] (lưu xuống SharedPreferences + notify).
/// Nhờ đó màn Trải bài (context.watch) cập nhật ngay khi Cài đặt
/// hoặc dialog đổi bàn thay đổi bất cứ thứ gì — không còn setting
/// nào "lưu mà không ai đọc" hay "đổi mà không có tác dụng".
///
/// Các danh sách lựa chọn hợp lệ nằm ở [UserPreferencesModel]
/// (tableStyles / clothStyles / decorOptions / themeIds) và được
/// dùng chung cho provider, SettingsScreen và dialog đổi bàn.
class SettingsProvider extends ChangeNotifier {
  final PreferencesService _prefsService = PreferencesService();
  UserPreferencesModel _userPrefs = UserPreferencesModel();
  bool _isLoaded = false;

  UserPreferencesModel get userPrefs => _userPrefs;
  bool get isLoaded => _isLoaded;

  AppThemeData get currentThemeData {
    return AppThemeData.availableThemes[_userPrefs.themeId] ??
        AppThemeData.availableThemes['default_dark']!;
  }

  /// Ngôn ngữ giao diện hiện tại, suy ra từ mã đã lưu
  /// ([UserPreferencesModel.languageCode]); mã lạ -> Tiếng Việt.
  AppLanguage get language {
    return AppLanguage.values.firstWhere(
      (l) => l.code == _userPrefs.languageCode,
      orElse: () => AppLanguage.vi,
    );
  }

  /// Đổi ngôn ngữ giao diện: chỉ nhận mã trong
  /// [UserPreferencesModel.languageCodes], lưu xuống
  /// SharedPreferences rồi notify để mọi màn hình (context.watch)
  /// vẽ lại bằng ngôn ngữ mới.
  void setLanguage(AppLanguage lang) {
    if (UserPreferencesModel.languageCodes.contains(lang.code)) {
      _userPrefs.languageCode = lang.code;
      _save();
    }
  }

  /// Dịch một chuỗi giao diện theo ngôn ngữ hiện tại.
  /// Thiếu key -> về Tiếng Việt, thiếu hẳn -> trả chính key đó,
  /// không bao giờ crash (xem [AppStrings.of]).
  String tr(String key) => AppStrings.of(language, key);

  Future<void> initSettings() async {
    _userPrefs = await _prefsService.loadPreferences();
    _isLoaded = true;
    notifyListeners();
  }

  void setTheme(String themeId) {
    if (AppThemeData.availableThemes.containsKey(themeId)) {
      _userPrefs.themeId = themeId;
      _save();
    }
  }

  void toggleGlassmorphism(bool value) {
    _userPrefs.enableGlassmorphism = value;
    _save();
  }

  void toggleSmokeParticles(bool value) {
    _userPrefs.enableSmokeParticles = value;
    _save();
  }

  void toggleTwinklingText(bool value) {
    _userPrefs.enableTwinklingText = value;
    _save();
  }

  /// Hiện pop-up hướng dẫn khi vào màn chính (sau đăng nhập / tải
  /// lại / vào bằng khách): true = hiện, false = đã ẩn. Lưu ngay
  /// để đóng dialog bằng cách bấm ngoài cũng không mất lựa chọn.
  void setShowGuidePopup(bool value) {
    _userPrefs.showGuidePopup = value;
    _save();
  }

  // Toggles cho 3 lớp hiển thị mặt bàn bói
  void toggleTable(bool value) {
    _userPrefs.showTable = value;
    _save();
  }

  void toggleCloth(bool value) {
    _userPrefs.showCloth = value;
    _save();
  }

  void toggleDecor(bool value) {
    _userPrefs.showDecor = value;
    _save();
  }

  void setTableStyle(String style) {
    if (UserPreferencesModel.tableStyles.contains(style)) {
      _userPrefs.tableStyle = style;
      _save();
    }
  }

  void setClothStyle(String style) {
    if (UserPreferencesModel.clothStyles.contains(style)) {
      _userPrefs.clothStyle = style;
      _save();
    }
  }

  /// Đặt danh sách decor: chỉ giữ món trong [UserPreferencesModel.decorOptions],
  /// bỏ trùng, tối đa [UserPreferencesModel.maxDecorItems] món.
  /// Đây là điểm chặn duy nhất — UI (Cài đặt / dialog đổi bàn) chỉ
  /// cần gọi setter này, không tự lọc ở từng nơi nữa.
  /// Đồng thời đồng bộ nút "Hiện đồ decor" với danh sách: còn món
  /// nào được chọn thì bật, bỏ chọn hết thì tắt — để nút luôn phản
  /// ánh đúng có decor hay không, ở cả hai màn hình.
  void setDecorItems(List<String> items) {
    final seen = <String>{};
    final clean = <String>[];
    for (final item in items) {
      if (UserPreferencesModel.decorOptions.contains(item) &&
          seen.add(item)) {
        clean.add(item);
      }
      if (clean.length == UserPreferencesModel.maxDecorItems) break;
    }
    _userPrefs.decorItems = clean;
    // Đồng bộ "Hiện đồ decor": chọn món nào -> bật; bỏ chọn hết
    // (danh sách rỗng) -> tắt. Nút vẫn bật/tắt tay được qua
    // toggleDecor, nhưng mỗi lần đổi danh sách decor là đồng bộ lại.
    _userPrefs.showDecor = clean.isNotEmpty;
    _save();
  }

  /// Kiểu trải bài trên bàn: 'single' (1 hàng) hoặc 'multi' (nhiều hàng).
  void setSpreadMode(String mode) {
    if (mode == 'single' || mode == 'multi') {
      _userPrefs.spreadMode = mode;
      _save();
    }
  }

  void _save() {
    _prefsService.savePreferences(_userPrefs);
    notifyListeners();
  }
}
