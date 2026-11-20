import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../data/datasources/preferences_service.dart';
import '../data/models/user_preferences.dart';

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

  void setCustomBackgroundImage(String? path) {
    _userPrefs.customBackgroundImagePath = path;
    _save();
  }

  void setTableStyle(String style) {
    _userPrefs.tableStyle = style;
    _save();
  }

  void setClothStyle(String style) {
    _userPrefs.clothStyle = style;
    _save();
  }

  void setDecorItems(List<String> items) {
    _userPrefs.decorItems = items.take(3).toList();
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
