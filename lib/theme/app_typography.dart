import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(TextTheme base) {
    final cairo = GoogleFonts.cairoTextTheme(base);
    return cairo.copyWith(
      displayLarge: cairo.displayLarge?.copyWith(fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: 0),
      displayMedium: cairo.displayMedium?.copyWith(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: 0),
      displaySmall: cairo.displaySmall?.copyWith(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 0),
      headlineLarge: cairo.headlineLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0),
      headlineMedium: cairo.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0),
      headlineSmall: cairo.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleLarge: cairo.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleMedium: cairo.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      titleSmall: cairo.titleSmall?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyLarge: cairo.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.6),
      bodyMedium: cairo.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.6),
      bodySmall: cairo.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.5),
      labelLarge: cairo.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      labelMedium: cairo.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0),
      labelSmall: cairo.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 0),
    );
  }
}
