import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType { black, white, skyBlue }

/// Brand palette shared by every theme.
abstract final class Brand {
  /// Champagne gold — primary brand accent.
  static const gold = Color(0xFFD4AF37);

  /// Softer gold for gradients and glows.
  static const champagne = Color(0xFFE8CE8C);

  /// Deep bronze — gradient partner for gold.
  static const bronze = Color(0xFF9C7A28);

  /// Near-black ink used on top of gold surfaces.
  static const onGold = Color(0xFF171204);
}

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

  /// Onyx — signature dark theme: deep charcoal with champagne-gold accents.
  static const black = AppColors(
    scaffoldBg: Color(0xFF0A0D13),
    cardBg: Color(0xFF121722),
    surfaceBg: Color(0xFF1A2130),
    border: Color(0xFF252E42),
    accentBlue: Brand.gold,
    textPrimary: Color(0xFFF3EFE4),
    textSecondary: Color(0xFF98A0B3),
    textMuted: Color(0xFF4A5368),
    iconColor: Color(0xFF98A0B3),
    success: Color(0xFF2EBD85),
    warning: Color(0xFFE8A33D),
    error: Color(0xFFE5484D),
    brightness: Brightness.dark,
  );

  /// Ivory — warm gallery-white with dark-gold accents.
  static const white = AppColors(
    scaffoldBg: Color(0xFFF7F5EF),
    cardBg: Color(0xFFFFFFFF),
    surfaceBg: Color(0xFFEFEBE1),
    border: Color(0xFFE3DED1),
    accentBlue: Color(0xFF9C7A28),
    textPrimary: Color(0xFF211E15),
    textSecondary: Color(0xFF6F6B5E),
    textMuted: Color(0xFFA9A495),
    iconColor: Color(0xFF6F6B5E),
    success: Color(0xFF1F7A4D),
    warning: Color(0xFFB26A00),
    error: Color(0xFFC93A3F),
    brightness: Brightness.light,
  );

  /// Steel — refined slate-blue alternative.
  static const skyBlue = AppColors(
    scaffoldBg: Color(0xFFEDF1F6),
    cardBg: Color(0xFFFFFFFF),
    surfaceBg: Color(0xFFE1E8F0),
    border: Color(0xFFD2DAE5),
    accentBlue: Color(0xFF1F3A5F),
    textPrimary: Color(0xFF15202E),
    textSecondary: Color(0xFF51637B),
    textMuted: Color(0xFF93A2B4),
    iconColor: Color(0xFF51637B),
    success: Color(0xFF22764C),
    warning: Color(0xFFAD6800),
    error: Color(0xFFBF3A44),
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
    final c = _colors;
    final isDark = c.brightness == Brightness.dark;

    OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      brightness: c.brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: c.scaffoldBg,
      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: c.accentBlue,
        onPrimary: isDark ? Brand.onGold : Colors.white,
        secondary: c.accentBlue,
        onSecondary: isDark ? Brand.onGold : Colors.white,
        surface: c.cardBg,
        onSurface: c.textPrimary,
        error: c.error,
        onError: Colors.white,
      ),
      cardColor: c.cardBg,
      dividerColor: c.border,
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        bodyLarge: TextStyle(color: c.textPrimary, height: 1.45),
        bodyMedium: TextStyle(color: c.textPrimary, height: 1.45),
      ),
      cardTheme: CardThemeData(
        color: c.cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.scaffoldBg,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? c.surfaceBg.withValues(alpha: 0.55) : c.surfaceBg.withValues(alpha: 0.35),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: fieldBorder(c.border),
        enabledBorder: fieldBorder(c.border),
        focusedBorder: fieldBorder(c.accentBlue, 1.4),
        labelStyle: TextStyle(color: c.textSecondary),
        hintStyle: TextStyle(color: c.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accentBlue,
          foregroundColor: isDark ? Brand.onGold : Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accentBlue),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? c.surfaceBg : c.textPrimary,
        contentTextStyle: TextStyle(color: isDark ? c.textPrimary : c.scaffoldBg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accentBlue),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.cardBg,
        selectedItemColor: c.accentBlue,
        unselectedItemColor: c.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.cardBg,
        indicatorColor: c.accentBlue.withValues(alpha: 0.18),
      ),
    );
  }
}
