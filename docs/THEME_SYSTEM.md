# Theme System — نظام إدارة موظفي المصنع

This document defines the application-wide color and theme rules. It is the source of truth for new UI work.

## Goals

- A professional HR/factory interface with low visual noise.
- Material 3 color roles generated from one brand seed.
- Full Light / Dark / System support.
- Consistent semantic meaning for success, warning, and error colors.
- No screen-specific color palettes that compete with each other.
- Readable text and controls with accessible contrast.

## Brand Color

The brand seed is deep teal:

- `AppColors.primary = #0F766E`

It communicates identity and is used by Material 3 to generate the primary tonal palette.

### Use primary for

- The most important action on a screen.
- Selected navigation destinations.
- Selected chips, segmented controls, and focus states.
- Small identity accents and key icons.

### Do not use primary for

- Every card background.
- Every icon in a dashboard.
- Large decorative surfaces.
- Success, warning, or error states.

## Structural Colors

All structural UI must use `Theme.of(context).colorScheme` roles.

Recommended roles:

- Page background: `scheme.surface`
- Main card: `scheme.surfaceContainerLowest`
- Secondary nested area: `scheme.surfaceContainerLow` / `scheme.surfaceContainer`
- Disabled or stronger neutral area: `scheme.surfaceContainerHighest`
- Main text: `scheme.onSurface`
- Secondary/meta text: `scheme.onSurfaceVariant`
- Borders/dividers: `scheme.outlineVariant`
- Stronger outline where necessary: `scheme.outline`

Do not hardcode white cards or grey text. Material 3 resolves these roles correctly for both brightness modes.

## Semantic Colors

Semantic colors communicate state, not decoration.

### Success

Use `context.semanticColors.success` and its container roles for:

- Approved
- Paid
- Completed
- Successful operation
- Confirmed attendance where green is genuinely meaningful

### Warning

Use `context.semanticColors.warning` and its container roles for:

- Pending approval
- Late
- Needs review
- Incomplete
- Attention that is not an error

### Error / destructive

Use `scheme.error`, `scheme.onError`, `scheme.errorContainer`, and `scheme.onErrorContainer` for:

- Rejected
- Invalid input
- Failed operation
- Absence when treated as a negative status
- Destructive confirmation buttons

Do not use semantic colors merely to make a dashboard more colorful.

## Status Components

Prefer:

- `AppStatusPill`
- `AppStatusBadge`

Every status must include a text label and may include an icon. Color alone must never carry the meaning.

## Cards

Cards are neutral by default.

- Background: neutral surface role.
- Border: subtle `outlineVariant`.
- Shadow: subtle and rare.
- Accent color is allowed on a small icon/value/badge, not the whole card.

Use `elevated: true` only when the card genuinely needs separation from surrounding content, not for every metric.

## Buttons

- `FilledButton`: primary/high-emphasis action.
- `FilledButton.tonal`: medium-emphasis supportive action.
- `OutlinedButton`: secondary action where a border helps recognition.
- `TextButton`: low-emphasis/cancel/navigation action.
- Destructive action: filled error color only when the consequence is destructive and clearly confirmed.

Avoid multiple equally strong filled buttons competing on one screen.

## Forms

Input fields use neutral surfaces and borders.

- Normal border: `outlineVariant`
- Focus border: `primary`
- Error border: `error`
- Labels/hints/icons: `onSurfaceVariant`

Do not fill every field with the brand color.

## Navigation

Bottom navigation remains neutral.

- Unselected icon/label: `onSurfaceVariant`
- Selected indicator: `primaryContainer`
- Selected icon: `onPrimaryContainer`
- Selected label: `primary`

This keeps the navigation visible without turning the whole bottom bar teal.

## Dark Theme

Dark mode is not a color inversion of the light theme. It uses Material 3 roles generated from the same brand seed plus dedicated semantic dark tones.

Rules:

- Never use fixed `Colors.white` as a card background.
- Never use fixed dark text colors.
- Avoid fixed legacy success/warning colors directly on dark surfaces.
- Reusable components that accept a legacy custom accent must adapt it to current brightness.

## Theme Preference

Theme preference is controlled only by `AppThemeController`.

Supported modes:

- `ThemeMode.system`
- `ThemeMode.light`
- `ThemeMode.dark`

The setting is persisted with `SharedPreferences` and exposed in the Settings screen.

## Typography

The app uses bundled Cairo (`assets/fonts/cairo/Cairo.ttf`) so the UI works offline and Arabic typography is stable.

Use `Theme.of(context).textTheme` roles rather than arbitrary font sizes.

## Contrast and Accessibility

The target is WCAG AA contrast for essential text:

- Normal text: at least 4.5:1.
- Large text: at least 3:1.

Selected/semantic states should also preserve a non-color cue through text, iconography, border, or shape.

## New Screen Checklist

Before merging a new UI screen:

1. No decorative hardcoded colors in the screen.
2. Structural colors come from `ColorScheme`.
3. Semantic status colors have real status meaning.
4. Main action is visually clear and not competing with several equally strong actions.
5. Cards are predominantly neutral.
6. Empty, loading, error, and dialogs use shared widgets.
7. Check both light and dark themes.
8. Check Arabic RTL layout.
9. Check phone-width overflow.
10. Run `dart format .` and `flutter analyze lib/`.
