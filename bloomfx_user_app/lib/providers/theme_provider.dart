import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType { black, white, skyBlue }

class AppColors {
  final Color scaffoldBg;
  final Color cardBg;
  final Color surfaceBg;
  final Color border;
  final Color accentBlue;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color iconColor;
  final Color success;
  final Color warning;
  final Color error;
  final Brightness brightness;

  const AppColors({
    required this.scaffoldBg,
    required this.cardBg,
    required this.surfaceBg,
    required this.border,
    required this.accentBlue,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.iconColor,
    required this.success,
    required this.warning,
    required this.error,
    required this.brightness,
  });

  static const black = AppColors(
    scaffoldBg: Color(0xFF0D1117),
    cardBg: Color(0xFF161B22),
    surfaceBg: Color(0xFF21262D),
    border: Color(0xFF30363D),
    accentBlue: Color(0xFF58A6FF),
    textPrimary: Colors.white,
    textSecondary: Color(0xFF7D8590),
    textMuted: Color(0xFF484F58),
    iconColor: Color(0xFF7D8590),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFA726),
    error: Color(0xFFEF5350),
    brightness: Brightness.dark,
  );

  static const white = AppColors(
    scaffoldBg: Color(0xFFF5F5F5),
    cardBg: Color(0xFFFFFFFF),
    surfaceBg: Color(0xFFE8E8E8),
    border: Color(0xFFE0E0E0),
    accentBlue: Color(0xFF1E3A8A),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF6B7280),
    textMuted: Color(0xFF9CA3AF),
    iconColor: Color(0xFF6B7280),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    brightness: Brightness.light,
  );

  static const skyBlue = AppColors(
    scaffoldBg: Color(0xFFE3F2FD),
    cardBg: Color(0xFFBBDEFB),
    surfaceBg: Color(0xFF90CAF9),
    border: Color(0xFF64B5F6),
    accentBlue: Color(0xFF1565C0),
    textPrimary: Color(0xFF0D47A1),
    textSecondary: Color(0xFF1565C0),
    textMuted: Color(0xFF42A5F5),
    iconColor: Color(0xFF1565C0),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFE65100),
    error: Color(0xFFC62828),
    brightness: Brightness.light,
  );

  static AppColors fromType(AppThemeType type) {
    switch (type) {
      case AppThemeType.black: return black;
      case AppThemeType.white: return white;
      case AppThemeType.skyBlue: return skyBlue;
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  static const _keyPrefix = 'app_theme_';

  AppThemeType _type = AppThemeType.black;
  late AppColors _colors;
  String _userId = '';
  bool _initialized = false;

  ThemeProvider() {
    _colors = AppColors.fromType(_type);
  }

  AppThemeType get type => _type;
  AppColors get colors => _colors;
  bool get isInitialized => _initialized;
  String get _storageKey => '$_keyPrefix${_userId.isEmpty ? 'guest' : _userId}';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null) {
      _type = AppThemeType.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeType.black,
      );
      _colors = AppColors.fromType(_type);
    }
    _initialized = true;
    notifyListeners();
  }

  void setUserId(String id) {
    if (_userId == id) return;
    _userId = id;
  }

  Future<void> setTheme(AppThemeType type) async {
    _type = type;
    _colors = AppColors.fromType(type);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, type.name);
  }

  ThemeData get themeData {
    return ThemeData(
      brightness: _colors.brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: _colors.scaffoldBg,
      colorScheme: ColorScheme(
        brightness: _colors.brightness,
        primary: _colors.accentBlue,
        onPrimary: _colors.textPrimary,
        secondary: _colors.accentBlue,
        onSecondary: _colors.textPrimary,
        surface: _colors.cardBg,
        onSurface: _colors.textPrimary,
        error: _colors.error,
        onError: Colors.white,
      ),
      cardColor: _colors.cardBg,
      dividerColor: _colors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: _colors.cardBg,
        foregroundColor: _colors.textPrimary,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _colors.cardBg,
        selectedItemColor: _colors.accentBlue,
        unselectedItemColor: _colors.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _colors.cardBg,
        indicatorColor: _colors.accentBlue.withValues(alpha: 0.2),
      ),
    );
  }
}
