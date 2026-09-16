import 'package:flutter/material.dart';

/// Цветовая палитра и стили дизайна Jira Time Tracker из дизайн-макета
/// (docs/design/jira-time-tracker-ux.html).
class AppColors {
  // Primary (Indigo)
  static const primaryLight = Color(0xFF5156C8);
  static const primaryDark = Color(0xFFBFC0FF);
  static const onPrimaryLight = Color(0xFFFFFFFF);
  static const onPrimaryDark = Color(0xFF22234E);

  // Background & Surface
  static const bgLight = Color(0xFFF7F8FC);
  static const bgDark = Color(0xFF191C24);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF242833);

  // Text
  static const textLight = Color(0xFF232838);
  static const textDark = Color(0xFFEDF0F7);
  static const mutedLight = Color(0xFF667086);
  static const mutedDark = Color(0xFFACB5C9);

  // Borders & Hover
  static const lineLight = Color(0xFFE1E5ED);
  static const lineDark = Color(0xFF3C4352);
  static const hoverLight = Color(0xFFF0F2F8);
  static const hoverDark = Color(0xFF2D3341);
  static const selectedLight = Color(0xFFEFEFFF);
  static const selectedDark = Color(0xFF34364F);

  // Status Colors
  static const greenLight = Color(0xFF247858);
  static const greenDark = Color(0xFF8FDDBC);
  static const greenBgLight = Color(0xFFEAF6F0);
  static const greenBgDark = Color(0xFF203D35);

  static const warnLight = Color(0xFF8E551D);
  static const warnDark = Color(0xFFF0C68C);
  static const warnBgLight = Color(0xFFFFF4E5);
  static const warnBgDark = Color(0xFF453522);

  static const errorLight = Color(0xFFB73748);
  static const errorDark = Color(0xFFFFABB6);

  // Timeline track segment colors
  static const trackOneLight = Color(0xFFB8BAF1);
  static const trackOneDark = Color(0xFF676AB0);
  static const trackTwoLight = Color(0xFF9DCFC4);
  static const trackTwoDark = Color(0xFF488678);
  static const trackExistingLight = Color(0xFFC6CBD7);
  static const trackExistingDark = Color(0xFF737D92);
  static const trackBreakLight = Color(0xFFE9ECF2);
  static const trackBreakDark = Color(0xFF333B48);

  static Color bg(bool isDark) => isDark ? bgDark : bgLight;
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color text(bool isDark) => isDark ? textDark : textLight;
  static Color muted(bool isDark) => isDark ? mutedDark : mutedLight;
  static Color line(bool isDark) => isDark ? lineDark : lineLight;
  static Color hover(bool isDark) => isDark ? hoverDark : hoverLight;
  static Color primary(bool isDark) => isDark ? primaryDark : primaryLight;
  static Color onPrimary(bool isDark) =>
      isDark ? onPrimaryDark : onPrimaryLight;
  static Color selected(bool isDark) => isDark ? selectedDark : selectedLight;
  static Color green(bool isDark) => isDark ? greenDark : greenLight;
  static Color greenBg(bool isDark) => isDark ? greenBgDark : greenBgLight;
  static Color warn(bool isDark) => isDark ? warnDark : warnLight;
  static Color warnBg(bool isDark) => isDark ? warnBgDark : warnBgLight;
  static Color error(bool isDark) => isDark ? errorDark : errorLight;

  static Color trackOne(bool isDark) => isDark ? trackOneDark : trackOneLight;
  static Color trackTwo(bool isDark) => isDark ? trackTwoDark : trackTwoLight;
  static Color trackExisting(bool isDark) =>
      isDark ? trackExistingDark : trackExistingLight;
  static Color trackBreak(bool isDark) =>
      isDark ? trackBreakDark : trackBreakLight;
}

class AppTheme {
  static ThemeData get lightTheme {
    return _buildTheme(isDark: false);
  }

  static ThemeData get darkTheme {
    return _buildTheme(isDark: true);
  }

  static ThemeData _buildTheme({required bool isDark}) {
    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: AppColors.primary(isDark),
      onPrimary: AppColors.onPrimary(isDark),
      primaryContainer: AppColors.selected(isDark),
      onPrimaryContainer: AppColors.primary(isDark),
      secondary: AppColors.trackTwo(isDark),
      onSecondary: isDark ? const Color(0xFF00382E) : Colors.white,
      surface: AppColors.surface(isDark),
      onSurface: AppColors.text(isDark),
      error: AppColors.error(isDark),
      onError: isDark ? const Color(0xFF680017) : Colors.white,
      outline: AppColors.line(isDark),
      outlineVariant: AppColors.line(isDark),
      surfaceContainerHighest: AppColors.hover(isDark),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg(isDark),
      fontFamily: 'Segoe UI',
      visualDensity: VisualDensity.compact,
      textTheme: TextTheme(
        bodyMedium: TextStyle(
          color: AppColors.text(isDark),
          fontSize: 14,
          height: 1.45,
        ),
        titleLarge: TextStyle(
          color: AppColors.text(isDark),
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.4,
        ),
        titleSmall: TextStyle(
          color: AppColors.text(isDark),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerColor: AppColors.line(isDark),
      dividerTheme: DividerThemeData(
        color: AppColors.line(isDark),
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface(isDark),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line(isDark)),
          borderRadius: BorderRadius.circular(9),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface(isDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        hintStyle: TextStyle(color: AppColors.muted(isDark), fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: AppColors.line(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: AppColors.line(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: AppColors.primary(isDark), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary(isDark),
          foregroundColor: AppColors.onPrimary(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary(isDark),
          foregroundColor: AppColors.onPrimary(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.surface(isDark),
          foregroundColor: AppColors.text(isDark),
          side: BorderSide(color: AppColors.line(isDark)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.muted(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          maximumSize: const Size(40, 40),
          padding: const EdgeInsets.all(6),
        ),
      ),
    );
  }
}
