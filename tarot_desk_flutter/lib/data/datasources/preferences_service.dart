import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

/// PreferencesService xử lý lưu trữ cấu hình người dùng bằng SharedPreferences
class PreferencesService {
  static const String _keyUserPrefs = 'tarotdesk_user_preferences';

  Future<UserPreferencesModel> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyUserPrefs);
      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonString);
        return UserPreferencesModel.fromMap(decoded);
      }
    } catch (_) {}
    return UserPreferencesModel();
  }

  Future<void> savePreferences(UserPreferencesModel userPrefs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(userPrefs.toMap());
      await prefs.setString(_keyUserPrefs, jsonString);
    } catch (_) {}
  }
}
