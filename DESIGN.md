# HR Employee System Design Guide & Architecture

## Design Personality

The product is an enterprise HR/factory employee system designed Arabic-first with complete English LTR capability. Its visual persona is **Professional**, **Modern**, **Calm**, **Clean**, **Trustworthy**, **Information-focused**, and **Low-noise**. Repeated operational readability is more important than decorative color.

## Theme Architecture

The application uses Material 3 and derives its structural palette from one brand seed through `ColorScheme.fromSeed`.

### Brand seed

- **Primary Teal (`#0F766E`)**

Use teal for high-emphasis actions, selected navigation, focus, and small identity accents. It is not a general card/background color.

### Structural color rule

Production screens should not choose independent structural colors. Use Material 3 roles from `Theme.of(context).colorScheme`:

- `surface`: page canvas.
- `surfaceContainerLowest`: primary card surface.
- `surfaceContainerLow` / `surfaceContainer`: nested or secondary surfaces.
- `surfaceContainerHighest`: stronger neutral separation/disabled surfaces.
- `onSurface`: primary readable content.
- `onSurfaceVariant`: metadata, hints, secondary text/icons.
- `outlineVariant`: subtle borders/dividers.
- `primary` / `primaryContainer`: high-emphasis action and selected state.

The generated scheme resolves the correct tones in both light and dark modes.

## Semantic Colors

Semantic colors are state-only and are never decorative module colors.

- **Success**: approved, paid, completed, successful operation.
- **Warning**: pending, late, incomplete, needs review.
- **Error/Danger**: error, rejected, absence when treated as a negative state, destructive actions.

Success and warning use `AppSemanticColors` through `context.semanticColors`. Error/destructive state uses `ColorScheme.error` roles.

Every semantic state must include a textual label and/or icon; color must not be the only cue.

## Where Color Should and Should Not Appear

### Good uses

- One primary call to action.
- Selected navigation destination.
- Selected chip/segmented control.
- Input focus border.
- Small icon/value accent in a neutral card.
- Status badge/pill with real semantic meaning.
- Error or destructive confirmation.

### Avoid

- Painting every dashboard card a different color.
- Using brand teal for success.
- Using green/amber/red as decorative category colors.
- Fixed white cards or fixed grey/black text in production screens.
- Multiple equally strong filled buttons competing on one screen.

## Surface & Elevation

Prefer tonal surface hierarchy and subtle borders over heavy shadows:

- Standard cards are neutral and use `outlineVariant`.
- Nested metric areas can use `surfaceContainer`.
- Shadows are reserved for genuinely elevated/focal cards and stay subtle.
- Dialogs and bottom sheets use theme surface roles rather than fixed light colors.

## Typography Scale

The application uses the bundled **Cairo** font through `AppTypography`, so Arabic typography works offline and remains stable.

- Display / Hero: 32–46 pt only where a true hero/display role exists.
- Screen titles: `titleLarge` / headline roles.
- Section headers: `titleMedium`.
- Card titles: `titleSmall`.
- Standard body: `bodyMedium`.
- Secondary descriptions: `bodySmall`.
- Labels / badges: label roles.

Do not introduce arbitrary font sizes when an existing `TextTheme` role communicates the hierarchy.

## Spacing & Geometry Tokens

- **Spacing Scale**: `4`, `8`, `12`, `16`, `20`, `24`, `32`, `40` through `AppSpacing`.
- **Corner Radii**:
  - Small: `8px` — chips/badges.
  - Medium: `12px` — inputs/buttons/sub-containers.
  - Large: `16px` — standard cards.
  - Extra Large: `20–24px` — dialogs/bottom sheets/focal surfaces.

Use `AppRadius` instead of introducing arbitrary radii in screens.

## Icon Scale

Use `AppIconSizes` where possible:

- Inline: `16px`.
- Small: `18px`.
- Standard/body: `22px`.
- Navigation/leading: approximately `24px`.
- Empty state: approximately `28–40px` depending on layout.

Large decorative icons should be rare.

## Theme Modes

The application supports:

- System
- Light
- Dark

`AppThemeController` owns the preference and persists it. Do not create parallel theme preference logic.

## Accessibility

Essential text targets WCAG AA contrast:

- Normal text: at least `4.5:1`.
- Large text: at least `3:1`.

Reusable status/accent components adapt legacy custom accent colors to current brightness where necessary.

## RTL / LTR Adaptability

- Prefer `EdgeInsetsDirectional`, `AlignmentDirectional`, and directional positioning.
- Use `TextAlign.start` / `TextAlign.end`.
- Direction-sensitive chevrons/arrows must follow locale direction.

## References

- Application theme implementation: `lib/theme/`.
- Theme usage rules: [`docs/THEME_SYSTEM.md`](docs/THEME_SYSTEM.md).
- Master design-system documentation: [`design-system/MASTER.md`](design-system/MASTER.md).
