// lib/themes/app_theme.dart — responsive-aware theme
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary    = Color(0xFF4ECDC4);
  static const Color secondary  = Color(0xFF45B7D1);
  static const Color bgLight    = Color(0xFFF2FFFF);
  static const Color bgDark     = Color(0xFF121212);
  static const Color surfLight  = Color(0xFFFFFFFF);
  static const Color surfDark   = Color(0xFF1E1E1E);
  static const Color cardDark   = Color(0xFF2D2D2D);
  static const Color error      = Color(0xFFFF6B6B);
  static const Color success    = Color(0xFF00B894);
  static const Color warning    = Color(0xFFFDCB6E);

  // ── LIGHT ─────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surfLight,
      error: error,
      onSurface: Color(0xFF2D3436),
      onPrimary: Colors.white,
    ),
    scaffoldBackgroundColor: bgLight,
    fontFamily: GoogleFonts.inter().fontFamily,

    appBarTheme: const AppBarTheme(
      backgroundColor: bgLight,
      foregroundColor: Color(0xFF2D3436),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          color: Color(0xFF2D3436),
          fontSize: 20,
          fontWeight: FontWeight.w600),
    ),

    // Bottom nav (mobile/tablet)
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfLight,
      selectedItemColor: primary,
      unselectedItemColor: Color(0xFF636E72),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      showUnselectedLabels: true,
    ),

    // Navigation rail (tablet sidebar)
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: surfLight,
      selectedIconTheme: IconThemeData(color: primary),
      unselectedIconTheme: IconThemeData(color: Color(0xFF636E72)),
      selectedLabelTextStyle: TextStyle(color: primary),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      color: surfLight,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfLight,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5)),
      labelStyle: const TextStyle(color: Color(0xFF636E72)),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),

    dividerTheme: const DividerThemeData(
        color: Color(0xFFE8ECF1), thickness: 1),
    chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFFF0F0F0),
        selectedColor: Color(0xFFD0F5F3)),
  );

  // ── DARK ──────────────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surfDark,
      error: error,
      onSurface: Color(0xFFECF0F1),
      onPrimary: Colors.white,
    ),
    scaffoldBackgroundColor: bgDark,
    fontFamily: GoogleFonts.inter().fontFamily,

    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      foregroundColor: Color(0xFFECF0F1),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          color: Color(0xFFECF0F1),
          fontSize: 20,
          fontWeight: FontWeight.w600),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfDark,
      selectedItemColor: primary,
      unselectedItemColor: Color(0xFF636E72),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      showUnselectedLabels: true,
    ),

    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: surfDark,
      selectedIconTheme: IconThemeData(color: primary),
      unselectedIconTheme: IconThemeData(color: Color(0xFF636E72)),
      selectedLabelTextStyle: TextStyle(color: primary),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      color: cardDark,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDark,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF444444))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF444444))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5)),
      labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),

    dividerTheme: const DividerThemeData(
        color: Color(0xFF333333), thickness: 1),
    chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFF2D2D2D),
        selectedColor: Color(0xFF1A4A48)),
  );
}