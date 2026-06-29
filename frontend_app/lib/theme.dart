import 'package:flutter/material.dart';

class HomiesColors {
  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const bg       = Color(0xFFF0EEE8);  // warm linen — earthy, not clinical
  static const surface  = Color(0xFFFEFDF9);  // warm white
  static const surface2 = Color(0xFFF3F1EB);  // recessed warm surface

  // ── Text ──────────────────────────────────────────────────────────────────
  static const text      = Color(0xFF1C1A16);  // warm near-black
  static const textDim   = Color(0xFF6B6258);  // warm stone
  static const textFaint = Color(0xFFACA49A);  // warm muted

  // ── Borders ───────────────────────────────────────────────────────────────
  static const border       = Color(0xFFE5DFD8);
  static const borderStrong = Color(0xFFCEC8BF);

  // ── Accent: muted sage-forest green ───────────────────────────────────────
  // Earthy and grounded — the opposite of a random AI colour pick.
  static const accent       = Color(0xFF496B58);
  static const accentSoft   = Color(0x16496B58);
  static const accentBorder = Color(0x44496B58);
  static const accentStrong = Color(0xFF324D3F);

  // ── OK / success: vivid forest (distinct shade from accent) ───────────────
  static const ok       = Color(0xFF27784B);
  static const okSoft   = Color(0x1627784B);
  static const okBorder = Color(0x4427784B);

  // ── Warning: warm amber ───────────────────────────────────────────────────
  static const warn       = Color(0xFFA07320);
  static const warnSoft   = Color(0x16A07320);
  static const warnBorder = Color(0x44A07320);

  // ── Danger: muted brick red (still clearly danger, not fire-engine red) ───
  static const danger       = Color(0xFFB54444);
  static const dangerSoft   = Color(0x16B54444);
  static const dangerBorder = Color(0x44B54444);
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
      headlineLarge:  TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: HomiesColors.text,    letterSpacing: -0.6, height: 1.2),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: HomiesColors.text,    letterSpacing: -0.4, height: 1.25),
      titleLarge:     TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: HomiesColors.text,    letterSpacing: -0.2),
      titleMedium:    TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: HomiesColors.text),
      bodyLarge:      TextStyle(fontSize: 15, color: HomiesColors.text,    height: 1.55),
      bodyMedium:     TextStyle(fontSize: 14, color: HomiesColors.text,    height: 1.5),
      bodySmall:      TextStyle(fontSize: 12, color: HomiesColors.textDim, height: 1.45),
      labelLarge:     TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: HomiesColors.text),
      labelMedium:    TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: HomiesColors.textDim),
      labelSmall:     TextStyle(fontSize: 11, color: HomiesColors.textFaint, letterSpacing: 0.2),
    ),

    cardTheme: CardThemeData(
      color: HomiesColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HomiesColors.border),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HomiesColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HomiesColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HomiesColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HomiesColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HomiesColors.danger, width: 1.5),
      ),
      hintStyle: const TextStyle(color: HomiesColors.textFaint, fontSize: 14),
      labelStyle: const TextStyle(color: HomiesColors.textDim, fontSize: 13),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: HomiesColors.surface,
      foregroundColor: HomiesColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: HomiesColors.text, size: 22),
      titleSpacing: 0,
    ),

    dividerTheme: const DividerThemeData(color: HomiesColors.border, thickness: 1, space: 16),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HomiesColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.1),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HomiesColors.text,
        side: const BorderSide(color: HomiesColors.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: HomiesColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: HomiesColors.surface,
      selectedItemColor: HomiesColors.accent,
      unselectedItemColor: HomiesColors.textFaint,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),

    chipTheme: const ChipThemeData(
      labelPadding: EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: StadiumBorder(),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: HomiesColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      shadowColor: const Color(0x28000000),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: HomiesColors.surface,
      elevation: 0,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: HomiesColors.text,
      contentTextStyle: const TextStyle(color: Color(0xFFEFEDE8), fontSize: 13, height: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? HomiesColors.accent : HomiesColors.textFaint),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? HomiesColors.accentSoft : const Color(0xFFE0DDD8)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}
