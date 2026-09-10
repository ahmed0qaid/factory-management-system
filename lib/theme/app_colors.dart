import 'package:flutter/material.dart';

/// Centralized Design System Colors for HR Employee System.
///
/// Grounded in 3 Main Color Axes:
/// - Primary: Teal (#0F766E) - Structural & Identity, Actions
/// - Secondary: Slate (#475569) - Neutral icons, secondary text, structural elements
/// - Tertiary: Amber (#B45309) - High-priority accent, non-error notifications
class AppColors {
  // ─── 3 Main Brand Color Axes ───
  static const primary = Color(0xFF0F766E);
  static const primaryDark = Color(0xFF115E59);
  static const primaryContainer = Color(0xFFCCFBF1);
  static const onPrimaryContainer = Color(0xFF115E59);

  static const secondary = Color(0xFF475569);
  static const secondaryDark = Color(0xFF334155);
  static const secondaryContainer = Color(0xFFF1F5F9);
  static const onSecondaryContainer = Color(0xFF334155);

  static const tertiary = Color(0xFFB45309);
  static const tertiaryDark = Color(0xFF92400E);
  static const tertiaryContainer = Color(0xFFFEF3C7);
  static const onTertiaryContainer = Color(0xFF92400E);

  // ─── Neutral Surfaces & Backgrounds ───
  static const background = Color(0xFFF8FAFC);
  static const darkBackground = Color(0xFF0F172A);
  static const surface = Colors.white;
  static const darkSurface = Color(0xFF172033);
  static const surfaceContainerLow = Color(0xFFF8FAFC);
  static const surfaceContainer = Color(0xFFF1F5F9);
  static const surfaceContainerHigh = Color(0xFFE2E8F0);
  static const border = Color(0xFFE2E8F0);
  static const cardBackground = Colors.white;

  // ─── Card Inactive Colors (Clean & Subtle) ───
  static const cardInactiveBackground = Colors.white;
  static const cardInactiveBorder = Color(0xFFE2E8F0);
  static const cardInactiveText = Color(0xFF94A3B8);

  // ─── Text ───
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // ─── Semantic Aliases ───
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);

  // ─── Helper Methods for Card Borders & Badges ───
  static Color infoCardBackground(Color color) => Colors.white;
  static Color infoCardBorder(Color color) => color.withValues(alpha: .35);
  static Color semanticBackground(Color color) => color.withValues(alpha: .08);
}
