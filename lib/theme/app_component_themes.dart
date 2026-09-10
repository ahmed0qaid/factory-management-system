import 'package:flutter/material.dart';

import 'app_radius.dart';
import 'app_spacing.dart';

class AppComponentThemes {
  const AppComponentThemes._();

  static AppBarTheme appBar(ColorScheme scheme, TextTheme textTheme) {
    return AppBarTheme(
      centerTitle: true,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        
      ),
    );
  }

  static CardThemeData card(ColorScheme scheme) {
    return CardThemeData(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .7)),
      ),
    );
  }

  static NavigationBarThemeData navigationBar(
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          size: selected ? 22 : 20,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          fontSize: 11,
          
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          height: 1.1,
        );
      }),
    );
  }

  static InputDecorationTheme input(ColorScheme scheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: scheme.error),
      ),
    );
  }

  static FilledButtonThemeData filledButton(ColorScheme scheme) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.normal),
      ),
    );
  }

  static OutlinedButtonThemeData outlinedButton(ColorScheme scheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.normal),
      ),
    );
  }

  static TextButtonThemeData textButton() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.normal),
      ),
    );
  }
}


