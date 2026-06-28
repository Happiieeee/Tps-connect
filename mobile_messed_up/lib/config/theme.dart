import 'package:flutter/material.dart';

class TPSTheme {
  // Brand colours
  static const Color primary        = Color(0xFF3B6D11);
  static const Color primaryDark    = Color(0xFF1a3a08);
  static const Color primaryLight   = Color(0xFF639922);
  static const Color accent         = Color(0xFF97C459);
  static const Color accentLight    = Color(0xFFEAF3DE);
  static const Color accentBorder   = Color(0xFFc0dd97);
  static const Color background     = Color(0xFFf7faf4);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color textDark       = Color(0xFF1a3a08);
  static const Color textMid        = Color(0xFF27500A);
  static const Color textLight      = Color(0xFF639922);
  static const Color textHint       = Color(0xFF97C459);
  static const Color error          = Color(0xFFE24B4A);
  static const Color warning        = Color(0xFFEF9F27);
  static const Color warningLight   = Color(0xFFfaeeda);

  static ThemeData get theme => ThemeData(
    fontFamily: 'DMSans',
    scaffoldBackgroundColor: background,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: accentLight,
      selectionHandleColor: primary,
    ),
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: surface,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: accentBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: accentBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: textHint),
      labelStyle: const TextStyle(color: textLight),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: accentBorder),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: background,
      selectedColor: primary,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: accentBorder),
      ),
    ),
  );
}

// Keep this top-level getter so main.dart's `theme: tpsTheme` still works
final ThemeData tpsTheme = TPSTheme.theme;
