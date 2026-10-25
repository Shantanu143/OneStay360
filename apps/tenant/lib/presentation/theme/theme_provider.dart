import 'package:flutter/material.dart';

enum AppThemeType {
  cyan,   // Ocean Cyan (Original)
  indigo, // Royal Indigo (Modern, premium)
  amber,  // Golden Hour (Warm, cozy)
  emerald, // Forest Premium (Sustainable, clean)
  plum,   // Sunset Chic (Bold, creative)
}

class ThemeProvider extends ChangeNotifier {
  AppThemeType _themeType = AppThemeType.indigo; // Default to Royal Indigo for a premium look

  AppThemeType get themeType => _themeType;

  void updateTheme(AppThemeType type) {
    if (_themeType != type) {
      _themeType = type;
      notifyListeners();
    }
  }

  String get themeName {
    switch (_themeType) {
      case AppThemeType.cyan:
        return 'Ocean Cyan';
      case AppThemeType.indigo:
        return 'Royal Indigo';
      case AppThemeType.amber:
        return 'Golden Hour';
      case AppThemeType.emerald:
        return 'Forest Premium';
      case AppThemeType.plum:
        return 'Sunset Chic';
    }
  }

  Color get primaryColor {
    switch (_themeType) {
      case AppThemeType.cyan:
        return const Color(0xFF06B6D4);
      case AppThemeType.indigo:
        return const Color(0xFF4F46E5);
      case AppThemeType.amber:
        return const Color(0xFFD97706);
      case AppThemeType.emerald:
        return const Color(0xFF059669);
      case AppThemeType.plum:
        return const Color(0xFF6D28D9);
    }
  }

  Color get secondaryColor {
    switch (_themeType) {
      case AppThemeType.cyan:
        return const Color(0xFF0891B2);
      case AppThemeType.indigo:
        return const Color(0xFF6366F1);
      case AppThemeType.amber:
        return const Color(0xFFF59E0B);
      case AppThemeType.emerald:
        return const Color(0xFF10B981);
      case AppThemeType.plum:
        return const Color(0xFFEC4899);
    }
  }

  ThemeData get currentThemeData {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
      ),
      primaryColor: primaryColor,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}
