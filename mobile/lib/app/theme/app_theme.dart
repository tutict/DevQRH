import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    const base = Color(0xFFF6F8FB);
    const panel = Color(0xFFFFFFFF);
    const ink = Color(0xFF17212B);
    const mutedInk = Color(0xFF526071);
    const accent = Color(0xFF0F766E);
    const secondary = Color(0xFF3B5B7A);
    const line = Color(0xFFD8E0EA);

    final textTheme = GoogleFonts.interTextTheme().copyWith(
      bodySmall: GoogleFonts.inter(color: mutedInk, fontSize: 13, height: 1.45),
      bodyMedium: GoogleFonts.inter(color: ink, fontSize: 15.5, height: 1.45),
      titleSmall: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        color: ink,
        fontSize: 13.5,
        height: 1.25,
      ),
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        color: ink,
        fontSize: 17,
        height: 1.25,
      ),
      headlineMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: ink,
        fontSize: 30,
        height: 1.08,
      ),
      headlineSmall: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: ink,
        fontSize: 23,
        height: 1.12,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: base,
      colorScheme: const ColorScheme.light(
        surface: panel,
        primary: accent,
        secondary: secondary,
        onPrimary: Colors.white,
        onSurface: ink,
        outline: line,
        surfaceContainerHighest: Color(0xFFEAF3F1),
        error: Color(0xFFB42318),
      ),
      textTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: line),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: accent.withValues(alpha: 0.12),
        side: const BorderSide(color: line),
        labelStyle: GoogleFonts.inter(
          color: ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel,
        indicatorColor: const Color(0xFFDDF3EF),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerColor: line,
    );
  }
}
