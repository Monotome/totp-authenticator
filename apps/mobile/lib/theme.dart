import 'package:flutter/material.dart';

/// App-wide color palette and theme data aligned with Windows 11 Modern Slate.
class AppTheme {
  // ── Brand Colors (Modern Slate) ──
  static const Color primaryDark = Color(0xFF0B0F19);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);
  static const Color accentSky = Color(0xFF38BDF8);
  static const Color accentCyan = Color(0xFF38BDF8); // Backward compatibility
  static const Color accentBlue = Color(0xFF0284C7);
  static const Color accentGreen = Color(0xFF4ADE80);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color textLight = Color(0xFFF8FAFC);
  static const Color textDim = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: accentSky,
        onPrimary: primaryDark,
        secondary: accentGreen,
        surface: surfaceDark,
        onSurface: textLight,
        outline: borderDark,
        error: accentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textLight),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textLight,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentSky,
        foregroundColor: primaryDark,
        elevation: 3,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentSky,
          foregroundColor: primaryDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textLight,
          side: const BorderSide(color: borderDark, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return textDim;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentSky;
          }
          return borderDark;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primaryDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: textDim, fontSize: 14),
        hintStyle: TextStyle(color: textDim.withValues(alpha: 0.6), fontSize: 14),
        prefixIconColor: textDim,
        suffixIconColor: textDim,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentSky, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentRed, width: 1),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    const lightBg = Color(0xFFF8FAFC);
    const lightBorder = Color(0xFFCBD5E1);
    const lightSurface = Colors.white;
    const lightText = Color(0xFF0F172A);

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0284C7),
        secondary: Color(0xFF059669),
        surface: lightSurface,
        onSurface: lightText,
        outline: lightBorder,
        error: accentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: lightText,
        ),
        iconTheme: IconThemeData(color: lightText),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF0284C7),
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightText,
          side: const BorderSide(color: lightBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFF64748B);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF0284C7);
          }
          return lightBorder;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIconColor: const Color(0xFF64748B),
        suffixIconColor: const Color(0xFF64748B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentRed, width: 1),
        ),
      ),
    );
  }
}
