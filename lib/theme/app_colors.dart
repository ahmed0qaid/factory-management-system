import 'package:flutter/material.dart';

/// Brand and compatibility colors for the factory employee system.
///
/// New UI should prefer Theme.of(context).colorScheme for structural colors
/// and AppSemanticColors for success/warning states. These constants remain as
/// compatibility aliases for legacy screens while the app migrates fully to
/// theme roles.
class AppColors {
  const AppColors._();

  // Brand seed. Deep teal keeps the system professional without making every
  // surface colorful. It is intended for high-emphasis actions and selection.
  static const primary = Color(0xFF0F766E);
  static const primaryDark = Color(0xFF115E59);
  static const primaryContainer = Color(0xFFD7F4EF);
  static const onPrimaryContainer = Color(0xFF073B37);

  // Neutral secondary axis for lower-emphasis structure and metadata.
  static const secondary = Color(0xFF52615E);
  static const secondaryDark = Color(0xFF394946);
  static const secondaryContainer = Color(0xFFDCE6E3);
  static const onSecondaryContainer = Color(0xFF17201E);

  // Warm accent. Reserve it for attention and non-error emphasis, not general
  // decoration.
  static const tertiary = Color(0xFF8A5A00);
  static const tertiaryDark = Color(0xFF664300);
  static const tertiaryContainer = Color(0xFFFFE2A8);
  static const onTertiaryContainer = Color(0xFF2C1C00);

  // Light compatibility surfaces. Theme-aware widgets should use ColorScheme
  // surface roles instead of these values directly.
  static const background = Color(0xFFF7FAF9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F7F6);
  static const surfaceContainer = Color(0xFFEDF2F0);
  static const surfaceContainerHigh = Color(0xFFE4EAE8);
  static const border = Color(0xFFDCE4E1);
  static const cardBackground = surface;

  // Dark compatibility values for older screens.
  static const darkBackground = Color(0xFF101413);
  static const darkSurface = Color(0xFF171C1A);

  // Inactive cards should stay neutral; selection should be communicated by
  // the theme primary roles rather than a strong fill.
  static const cardInactiveBackground = surface;
  static const cardInactiveBorder = border;
  static const cardInactiveText = Color(0xFF7B8985);

  // Text compatibility aliases.
  static const textPrimary = Color(0xFF17201E);
  static const textSecondary = Color(0xFF596662);
  static const textMuted = Color(0xFF7B8985);

  // Semantic compatibility aliases. New widgets should use AppSemanticColors
  // or ColorScheme.error so light/dark themes can resolve the correct tone.
  static const success = Color(0xFF287A32);
  static const warning = Color(0xFF815100);
  static const danger = Color(0xFFBA1A1A);

  static Color infoCardBackground(Color color) => color.withValues(alpha: .06);
  static Color infoCardBorder(Color color) => color.withValues(alpha: .28);
  static Color semanticBackground(Color color) => color.withValues(alpha: .10);
}
