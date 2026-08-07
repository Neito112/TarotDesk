import 'package:flutter/material.dart';

/// Quản lý màu sắc và giao diện chủ đề cho ứng dụng TarotDesk
class AppThemeData {
  final String id;
  final String nameVi;
  final Color backgroundColor;
  final Color cardBackgroundColor;
  final Color primaryColor;
  final Color accentColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color glassBorderColor;

  const AppThemeData({
    required this.id,
    required this.nameVi,
    required this.backgroundColor,
    required this.cardBackgroundColor,
    required this.primaryColor,
    required this.accentColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.glassBorderColor,
  });

  static final Map<String, AppThemeData> availableThemes = {
    'default_dark': const AppThemeData(
      id: 'default_dark',
      nameVi: 'Tối Obsidian (Mặc định)',
      backgroundColor: Color(0xFF0F0E17),
      cardBackgroundColor: Color(0x331F1D2B),
      primaryColor: Color(0xFFFFD700), // Vàng hoàng kim
      accentColor: Color(0xFF9D4EDD), // Tím ánh kim
      textColor: Colors.white,
      secondaryTextColor: Color(0xFFA7A9BE),
      glassBorderColor: Color(0x33FFFFFF),
    ),
    'mystical_purple': const AppThemeData(
      id: 'mystical_purple',
      nameVi: 'Tím Huyền Bí',
      backgroundColor: Color(0xFF16002C),
      cardBackgroundColor: Color(0x443C096C),
      primaryColor: Color(0xFFE0AAFF),
      accentColor: Color(0xFF7B2CBF),
      textColor: Color(0xFFF8F7FF),
      secondaryTextColor: Color(0xFFC77DFF),
      glassBorderColor: Color(0x44E0AAFF),
    ),
    'golden_sun': const AppThemeData(
      id: 'golden_sun',
      nameVi: 'Hoàng Kim Nắng Ấm',
      backgroundColor: Color(0xFF1C1917),
      cardBackgroundColor: Color(0x3344403C),
      primaryColor: Color(0xFFF59E0B),
      accentColor: Color(0xFFFBBF24),
      textColor: Color(0xFFFFFBEB),
      secondaryTextColor: Color(0xFFD97706),
      glassBorderColor: Color(0x44F59E0B),
    ),
    'gothic_night': const AppThemeData(
      id: 'gothic_night',
      nameVi: 'Đêm Gothic Tinh Tế',
      backgroundColor: Color(0xFF090A0F),
      cardBackgroundColor: Color(0x33181A20),
      primaryColor: Color(0xFFE63946),
      accentColor: Color(0xFFF1FAEE),
      textColor: Colors.white,
      secondaryTextColor: Color(0xFFA8DADC),
      glassBorderColor: Color(0x33E63946),
    ),
  };
}
