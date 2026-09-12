import 'package:flutter/material.dart';

class AppTypography {
  const AppTypography._();

  /// Cairo is bundled with the application, so typography stays available
  /// offline and does not depend on a runtime font download.
  static TextTheme textTheme(TextTheme base) {
    final cairo = base.apply(
      fontFamily: 'Cairo',
      bodyColor: base.bodyMedium?.color,
      displayColor: base.bodyMedium?.color,
    );

    return cairo.copyWith(
      displayLarge: cairo.displayLarge?.copyWith(
        fontSize: 46,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.25,
      ),
      displayMedium: cairo.displayMedium?.copyWith(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.25,
      ),
      displaySmall: cairo.displaySmall?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.3,
      ),
      headlineLarge: cairo.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.35,
      ),
      headlineMedium: cairo.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.35,
      ),
      headlineSmall: cairo.headlineSmall?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.4,
      ),
      titleLarge: cairo.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.4,
      ),
      titleMedium: cairo.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.45,
      ),
      titleSmall: cairo.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.45,
      ),
      bodyLarge: cairo.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.65,
      ),
      bodyMedium: cairo.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.6,
      ),
      bodySmall: cairo.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.55,
      ),
      labelLarge: cairo.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: cairo.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelSmall: cairo.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    );
  }
}
