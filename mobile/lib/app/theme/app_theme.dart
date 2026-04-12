import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    const base = Color(0xFFF5F0E7);
    const panel = Color(0xFFFFFCF6);
    const ink = Color(0xFF171411);
    const accent = Color(0xFFD95C18);
    const line = Color(0xFFE0D5C4);

    final textTheme = GoogleFonts.spaceGroteskTextTheme().copyWith(
      bodyMedium: GoogleFonts.spaceGrotesk(
        color: ink,
        fontSize: 15,
        height: 1.35,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        color: ink,
        fontSize: 32,
        height: 1.0,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        color: ink,
        fontSize: 24,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: base,
      colorScheme: const ColorScheme.light(
        surface: panel,
        primary: accent,
        secondary: ink,
        onPrimary: Colors.white,
        onSurface: ink,
        outline: line,
      ),
      textTheme: textTheme,
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
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: line, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: line, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panel,
        selectedColor: accent.withValues(alpha: 0.12),
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: line,
    );
  }
}
