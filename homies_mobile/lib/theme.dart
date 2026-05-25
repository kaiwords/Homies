import 'package:flutter/material.dart';

class HomiesColors {
  static const bg = Color(0xFFF7F6F3);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFFAF9F6);
  static const text = Color(0xFF2A2730);
  static const textDim = Color(0xFF6B6375);
  static const textFaint = Color(0xFF9C95A4);
  static const border = Color(0xFFE8E5E0);
  static const borderStrong = Color(0xFFD9D5CF);
  static const accent = Color(0xFFE85A4F);
  static const accentSoft = Color(0x1AE85A4F);
  static const accentStrong = Color(0xFFC8473D);
  static const ok = Color(0xFF2F855A);
  static const okSoft = Color(0x1A2F855A);
  static const warn = Color(0xFFB7791F);
  static const warnSoft = Color(0x1FB7791F);
  static const danger = Color(0xFFC53030);
  static const dangerSoft = Color(0x1AC53030);
}

ThemeData buildHomiesTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: HomiesColors.accent,
    primary: HomiesColors.accent,
    surface: HomiesColors.surface,
    onSurface: HomiesColors.text,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: HomiesColors.bg,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: HomiesColors.text),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: HomiesColors.text),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: HomiesColors.text),
      bodyMedium: TextStyle(fontSize: 14, color: HomiesColors.text),
      bodySmall: TextStyle(fontSize: 12, color: HomiesColors.textDim),
    ),
    cardTheme: CardThemeData(
      color: HomiesColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: HomiesColors.border),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HomiesColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: HomiesColors.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: HomiesColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: HomiesColors.textDim, fontSize: 13),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: HomiesColors.surface,
      foregroundColor: HomiesColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: HomiesColors.text),
    ),
    dividerTheme: const DividerThemeData(color: HomiesColors.border, thickness: 1, space: 16),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HomiesColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HomiesColors.text,
        side: const BorderSide(color: HomiesColors.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: HomiesColors.textDim,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: HomiesColors.surface,
      selectedItemColor: HomiesColors.accent,
      unselectedItemColor: HomiesColors.textDim,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
  );
}
