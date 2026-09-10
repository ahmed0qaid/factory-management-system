import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_component_themes.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get light {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    final colorScheme = baseScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
    );

    return _build(colorScheme, AppColors.background);
  }

  static ThemeData get dark {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
      error: const Color(0xFFF87171),
    );

    final colorScheme = baseScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
    );

    return _build(colorScheme, AppColors.darkBackground);
  }

  static ThemeData _build(ColorScheme colorScheme, Color background) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
    );
    final textTheme = AppTypography.textTheme(baseTheme.textTheme);

    return baseTheme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: GoogleFonts.cairoTextTheme(baseTheme.primaryTextTheme),
      appBarTheme: AppComponentThemes.appBar(colorScheme, textTheme),
      cardTheme: AppComponentThemes.card(colorScheme),
      inputDecorationTheme: AppComponentThemes.input(colorScheme),
      navigationBarTheme: AppComponentThemes.navigationBar(
        colorScheme,
        textTheme,
      ),
      filledButtonTheme: AppComponentThemes.filledButton(colorScheme),
      outlinedButtonTheme: AppComponentThemes.outlinedButton(colorScheme),
      textButtonTheme: AppComponentThemes.textButton(),
      chipTheme: baseTheme.chipTheme.copyWith(
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: textTheme.titleSmall,
        dataTextStyle: textTheme.bodyMedium,
        dividerThickness: 1,
      ),
    );
  }
}
