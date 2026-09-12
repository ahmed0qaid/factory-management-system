# HR Design System — Master Reference Guide

This document is the source of truth for the HR Employee System UI/UX. Future UI work must follow these tokens and role-based theming rules.

---

## 1. Design Personality & Philosophy

- **Target Context**: Enterprise HR/factory operational app (Arabic-first, English LTR compliant).
- **Aesthetic Attributes**: Professional, modern, calm, clean, trustworthy, information-focused, low visual noise.
- **Principles**:
  1. Information density over decoration.
  2. One primary brand identity; color is used sparingly.
  3. Semantic colors are reserved for real state meaning.
  4. Subtle `outlineVariant` borders and tonal surfaces instead of heavy shadows.
  5. Material 3 roles must work in Light and Dark themes.
  6. Status meaning is never communicated by color alone.

---

## 2. Token Specifications Summary

| Token Category | Specification | Code Reference |
| :--- | :--- | :--- |
| **Brand seed** | Deep Teal `#0F766E` | `AppColors.primary` / `ColorScheme.fromSeed` |
| **Structural colors** | Material 3 generated roles | `Theme.of(context).colorScheme` |
| **Success** | Theme-aware green roles | `context.semanticColors.success*` |
| **Warning** | Theme-aware amber roles | `context.semanticColors.warning*` |
| **Error / destructive** | Material 3 error roles | `colorScheme.error*` |
| **Surface hierarchy** | `surface`, `surfaceContainer*` | `ColorScheme` |
| **Borders** | `outlineVariant` / `outline` | `ColorScheme` |
| **Spacing Scale** | `4`, `8`, `12`, `16`, `20`, `24`, `32`, `40` | `AppSpacing` |
| **Card Radius** | Standard `16px` | `AppRadius` |
| **Font Family** | Bundled Cairo asset | `AppTypography` |
| **Icon Sizes** | Central size scale | `AppIconSizes` |
| **Theme mode** | System / Light / Dark | `AppThemeController` |

`AppColors` remains a compatibility layer for legacy code. New production screen styling should prefer `ColorScheme` and `AppSemanticColors`.

---

## 3. Color Usage Rules

### Primary teal

Use for:
- primary/high-emphasis actions,
- selected navigation,
- focused form fields,
- selected controls,
- small identity accents.

Do not use it to color every card or as a success color.

### Neutral surfaces

Cards and page structure are predominantly neutral:
- page: `surface`,
- primary card: `surfaceContainerLowest`,
- nested metric areas: `surfaceContainerLow` / `surfaceContainer`,
- stronger neutral/disabled area: `surfaceContainerHighest`,
- metadata text/icons: `onSurfaceVariant`,
- borders: `outlineVariant`.

### Semantic roles

- **Green**: approved, paid, completed, successful.
- **Amber**: pending, late, incomplete, needs review, attention.
- **Red/Error**: failed, rejected, invalid, destructive, absence when represented as a negative state.

Semantic colors must not be decorative category colors.

---

## 4. Detailed Documentation Index

- [Theme system and usage guide](../docs/THEME_SYSTEM.md)
- [Colors & ColorScheme Roles](colors.md)
- [Typography & TextTheme Scale](typography.md)
- [Spacing & Layout Tokens](spacing.md)
- [Shapes, Radius & Elevation](shapes.md)
- [Icons & Micro-Interactions](icons.md)
- [Accessibility & Contrast Standards](accessibility.md)
- **Components**:
  - [Cards](components/cards.md)
  - [Buttons & Actions](components/buttons.md)
  - [Inputs & Forms](components/inputs.md)
  - [Badges & Indicators](components/badges.md)
  - [Navigation Elements](components/navigation.md)
  - [Dialogs & Modals](components/dialogs.md)

---

## 5. Strict Enforcement Rules

1. **No decorative hardcoded colors** in production screens. Structural styling comes from `ColorScheme`.
2. **No fixed white/black/grey assumptions** for surfaces or text; they break Dark mode.
3. **Semantic colors require semantic meaning**. Use `context.semanticColors` for success/warning and `colorScheme.error` for error/destructive states.
4. **Neutral cards first**. Accent color belongs on a small icon, selected state, value, or status—not the whole module card.
5. **Use TextTheme roles** instead of arbitrary font-size hierarchies.
6. **Use AppSpacing and AppRadius** instead of arbitrary spacing/radius additions.
7. **Preserve business logic** during design-system-only work.
8. **Automatic directionality**: use directional padding/alignment/icons where direction matters.
9. **Verify Light and Dark** for every shared component and major screen.
10. Run `dart format .` and `flutter analyze lib/` after theme changes.
