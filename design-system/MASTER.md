# HR Design System — Master Reference Guide (MASTER.md)

This document is the absolute **Source of Truth** for the HR Employee System UI/UX. Any future agent or developer MUST adhere to the standards, tokens, and rules documented herein.

---

## 1. Design Personality & Philosophy

- **Target Context**: Enterprise HR operational app (Arabic-first, English LTR compliant).
- **Aesthetic Attributes**: Professional, Modern, Calm, Clean, Trustworthy, Low Visual Noise.
- **Principles**:
  1. Information density over decoration.
  2. Single primary color identity, restricted secondary and tertiary accents.
  3. Semantic colors are strictly reserved for actual state indicators (Present, Late, Absent, Approved, Pending, Rejected).
  4. Subtle borders (`outlineVariant`) instead of dark shadows.
  5. Soft neutral surfaces with M3 surface containers.

---

## 2. Token Specifications Summary

| Token Category | Value Scale / Specifications | Code Reference |
| :--- | :--- | :--- |
| **Primary Color** | `#0F766E` (Deep Teal) | `AppColors.primary` |
| **Secondary Color** | `#475569` (Slate Grey) | `AppColors.secondary` |
| **Tertiary Color** | `#B45309` (Warm Amber) | `AppColors.tertiary` |
| **Success Color** | `#16A34A` (Forest Green) | `AppColors.success` |
| **Warning Color** | `#D97706` (Amber Orange) | `AppColors.warning` |
| **Danger Color** | `#DC2626` (Bright Red) | `AppColors.danger` |
| **Surface Background**| `#FFFFFF` (Light) / `#0F172A` (Dark) | `ColorScheme.surface` |
| **Spacing Scale** | `4`, `8`, `12`, `16`, `20`, `24`, `32`, `40` | `AppSpacing` |
| **Card Radius** | `16px` (Standard) | `AppRadius.lg` |
| **Font Family** | Cairo (`google_fonts`) | `AppTypography` |
| **Icon Sizes** | `16`, `18`, `22`, `24`, `40`, `48` | `AppIconSizes` |

---

## 3. Detailed Modular Documentation Index

- [Colors & ColorScheme Roles](colors.md)
- [Typography & TextTheme Scale](typography.md)
- [Spacing & Layout Tokens](spacing.md)
- [Shapes, Radius & Elevation](shapes.md)
- [Icons & Micro-Interactions](icons.md)
- [Accessibility & Contrast Standards](accessibility.md)
- **Components**:
  - [Cards (Stat, Action, Status)](components/cards.md)
  - [Buttons & Actions](components/buttons.md)
  - [Inputs & Forms](components/inputs.md)
  - [Badges & Indicators](components/badges.md)
  - [Navigation Elements](components/navigation.md)
  - [Dialogs & Modals](components/dialogs.md)

---

## 4. Strict Enforcement Rules for Agents

1. **No Hardcoded Colors**: Never use `Colors.blue`, `Colors.red`, or hex literals inside screens. Use `Theme.of(context).colorScheme` or `AppColors`.
2. **No Random Font Sizes**: Always use `Theme.of(context).textTheme.titleMedium` or `AppTypography` text styles.
3. **No Hardcoded Spacing/Radius**: Use `AppSpacing` and `AppRadius` constants.
4. **Preserve Business Logic**: Never touch controllers, services, repositories, or database models. UI modifications only.
5. **Auto Directionality**: Use `EdgeInsetsDirectional` and `AlignmentDirectional` to guarantee seamless Arabic RTL and English LTR support.
