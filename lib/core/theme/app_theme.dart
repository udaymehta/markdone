import 'package:flutter/material.dart';

/// MarkDone! brand colors – a distinctive warm amber accent
/// paired with deep surface tones for a modern, minimal aesthetic.
class AppColors {
  AppColors._();

  // Primary accent – warm amber/orange
  static const Color accent = Color(0xFFFF6B35);
  static const Color accentLight = Color(0xFFFF9A6C);
  static const Color accentDark = Color(0xFFD94F1E);

  // Dark theme surfaces
  static const Color darkSurface = Color(0xFF121216);
  static const Color darkSurfaceVariant = Color(0xFF1C1C22);
  static const Color darkCard = Color(0xFF1E1E26);
  static const Color darkCardHover = Color(0xFF26262F);

  // Light theme surfaces
  static const Color lightSurface = Color(0xFFFAFAFC);
  static const Color lightSurfaceVariant = Color(0xFFF0F0F5);
  static const Color lightCard = Color(0xFFFFFFFF);

  // Text
  static const Color darkText = Color(0xFFF2F2F7);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color lightText = Color(0xFF1C1C1E);
  static const Color lightTextSecondary = Color(0xFF636366);

  // Status
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFFCC02);
  static const Color error = Color(0xFFFF3B30);

  // D-Day urgency
  static const Color ddayUrgent = Color(0xFFFF3B30);
  static const Color ddaySoon = Color(0xFFFF9500);
  static const Color ddayRelaxed = Color(0xFF30D158);
}

class AppTheme {
  AppTheme._();

  static ThemeData darkTheme([Color accent = AppColors.accent]) {
    final accentLight = _shiftLightness(accent, 0.12);
    final accentDark = _shiftLightness(accent, -0.12);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: accentDark,
        secondary: accentLight,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        onSurfaceVariant: AppColors.darkTextSecondary,
        error: AppColors.error,
        outline: Colors.white.withValues(alpha: 0.12),
      ),
      scaffoldBackgroundColor: AppColors.darkSurface,
      cardColor: AppColors.darkCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        selectedColor: accent.withValues(alpha: 0.2),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        thickness: 1,
      ),
      textTheme: _buildTextTheme(
        AppColors.darkText,
        AppColors.darkTextSecondary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCard,
        contentTextStyle: const TextStyle(color: AppColors.darkText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData lightTheme([Color accent = AppColors.accent]) {
    final accentLight = _shiftLightness(accent, 0.12);
    final accentDark = _shiftLightness(accent, -0.12);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: accentLight,
        secondary: accentDark,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        onSurfaceVariant: AppColors.lightTextSecondary,
        error: AppColors.error,
        outline: Colors.black.withValues(alpha: 0.08),
      ),
      scaffoldBackgroundColor: AppColors.lightSurface,
      cardColor: AppColors.lightCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightText,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceVariant,
        selectedColor: accent.withValues(alpha: 0.15),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.06),
        thickness: 1,
      ),
      textTheme: _buildTextTheme(
        AppColors.lightText,
        AppColors.lightTextSecondary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightCard,
        contentTextStyle: const TextStyle(color: AppColors.lightText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Color _shiftLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    final adjusted = (hsl.lightness + delta).clamp(0.0, 1.0);
    return hsl.withLightness(adjusted).toColor();
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
