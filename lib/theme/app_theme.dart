import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_component_themes.dart';
import 'app_semantic_colors.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    // Material 3 color roles are generated from one brand seed so actions,
    // containers, neutral surfaces and dark-mode tones stay coherent instead
    // of assigning unrelated colors widget by widget.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    final semanticColors = brightness == Brightness.dark
        ? AppSemanticColors.dark
        : AppSemanticColors.light;

    final baseTheme = ThemeData.from(
      colorScheme: colorScheme,
      useMaterial3: true,
    );
    final textTheme = AppTypography.textTheme(baseTheme.textTheme);

    return baseTheme.copyWith(
      extensions: <ThemeExtension<dynamic>>[semanticColors],
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      dividerColor: colorScheme.outlineVariant,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 22),
      appBarTheme: AppComponentThemes.appBar(colorScheme, textTheme),
      cardTheme: AppComponentThemes.card(colorScheme),
      inputDecorationTheme: AppComponentThemes.input(colorScheme),
      navigationBarTheme: AppComponentThemes.navigationBar(
        colorScheme,
        textTheme,
      ),
      filledButtonTheme: AppComponentThemes.filledButton(colorScheme),
      elevatedButtonTheme: AppComponentThemes.elevatedButton(colorScheme),
      outlinedButtonTheme: AppComponentThemes.outlinedButton(colorScheme),
      textButtonTheme: AppComponentThemes.textButton(colorScheme),
      iconButtonTheme: AppComponentThemes.iconButton(colorScheme),
      floatingActionButtonTheme: AppComponentThemes.floatingActionButton(
        colorScheme,
      ),
      listTileTheme: AppComponentThemes.listTile(colorScheme, textTheme),
      switchTheme: AppComponentThemes.switchTheme(colorScheme),
      checkboxTheme: AppComponentThemes.checkbox(colorScheme),
      radioTheme: AppComponentThemes.radio(colorScheme),
      segmentedButtonTheme: AppComponentThemes.segmentedButton(colorScheme),
      popupMenuTheme: AppComponentThemes.popupMenu(colorScheme, textTheme),
      datePickerTheme: AppComponentThemes.datePicker(colorScheme),
      timePickerTheme: AppComponentThemes.timePicker(colorScheme),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedColor: colorScheme.secondaryContainer,
        disabledColor: colorScheme.surfaceContainerLow,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
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
        actionTextColor: colorScheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surfaceContainerLow,
        modalBarrierColor: Colors.black.withValues(alpha: .38),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerLow,
        ),
        headingTextStyle: textTheme.titleSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        dividerThickness: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        collapsedTextColor: colorScheme.onSurface,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
    );
  }
}
