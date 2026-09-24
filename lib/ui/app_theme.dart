import 'package:flutter/material.dart';

/// Цвета макета Pencil (страницы 01–08); смысл состояний задаёт приложение.
class AppColors {
  // Primary
  static const primaryLight = Color(0xFF4059D8);
  static const primaryDark = Color(0xFF97AAFF);
  static const onPrimaryLight = Color(0xFFFFFFFF);
  static const onPrimaryDark = Color(0xFF152045);
  static const actionDark = Color(0xFF758EFA);
  static const onActionDark = Color(0xFF10182F);

  // Background & Surface
  static const bgLight = Color(0xFFFFFFFF);
  static const bgDark = Color(0xFF1B1E25);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1B1E25);
  static const insetDark = Color(0xFF15181E);

  // Text
  static const textLight = Color(0xFF20242C);
  static const textDark = Color(0xFFECEEF3);
  static const mutedLight = Color(0xFF667080);
  static const mutedDark = Color(0xFFA1AABA);

  // Borders & Hover
  static const lineLight = Color(0xFFE4E7EC);
  static const lineDark = Color(0xFF323844);
  static const hoverLight = Color(0xFFF6F7F9);
  static const hoverDark = Color(0xFF242A35);
  static const selectedLight = Color(0xFFEEF1FF);
  static const selectedDark = Color(0xFF252E4B);

  // Status Colors
  static const greenLight = Color(0xFF26735B);
  static const greenDark = Color(0xFF8ED1B1);
  static const greenBgLight = Color(0xFFEDF7F1);
  static const greenBgDark = Color(0xFF203A32);

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
  static Color inset(bool isDark) => isDark ? insetDark : surfaceLight;
  static Color text(bool isDark) => isDark ? textDark : textLight;
  static Color muted(bool isDark) => isDark ? mutedDark : mutedLight;
  static Color line(bool isDark) => isDark ? lineDark : lineLight;
  static Color hover(bool isDark) => isDark ? hoverDark : hoverLight;
  static Color primary(bool isDark) => isDark ? primaryDark : primaryLight;
  static Color onPrimary(bool isDark) =>
      isDark ? onPrimaryDark : onPrimaryLight;
  static Color action(bool isDark) => isDark ? actionDark : primaryLight;
  static Color onAction(bool isDark) =>
      isDark ? onActionDark : onPrimaryLight;
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
      onSurfaceVariant: AppColors.muted(isDark),
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
      fontFamily: 'Inter',
      visualDensity: VisualDensity.compact,
      textTheme: TextTheme(
        bodyMedium: TextStyle(
          color: AppColors.text(isDark),
          fontSize: 14,
          height: 1.45,
        ),
        titleLarge: TextStyle(
          color: AppColors.text(isDark),
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
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
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface(isDark),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line(isDark)),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface(isDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        hintStyle: TextStyle(color: AppColors.muted(isDark), fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: AppColors.line(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: AppColors.line(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: AppColors.primary(isDark), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.action(isDark),
          foregroundColor: AppColors.onAction(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.action(isDark),
          foregroundColor: AppColors.onAction(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.muted(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(
          color: isDark ? const Color(0xFF707C91) : AppColors.mutedLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
