# HR Employee System Design Guide & Architecture

## Design Personality

The product is an enterprise HR system designed Arabic-first with complete English LTR capability. Its visual persona is **Professional**, **Modern**, **Calm**, **Clean**, **Trustworthy**, **Information-focused**, and **Minimal Visual Noise**. Visual choices prioritize repeated operational readability over decorative spectacle.

## 3 Core Color Axes (Material 3)

The design system is grounded in 3 primary color axes:

1. **Primary Teal (`#0F766E`)**: Primary buttons, active navigation, key indicators, hero elements.
2. **Secondary Slate (`#475569`)**: Neutral icons, secondary text, subtle borders, inactive navigation, structural elements.
3. **Tertiary Amber (`#B45309`)**: High-priority accent, secondary emphasis, non-error notifications requiring attention.

### Semantic Colors
- **Success (`#16A34A`)**: Attendance present, approved requests, completed payments, operational success.
- **Warning (`#D97706`)**: Late check-in, pending review, attention required.
- **Danger (`#DC2626`)**: Absence, rejected requests, destructive actions.

*Rule: Semantic colors are strictly restricted to actual system states and MUST NOT be used for decorative or quick-action styling.*

## Surface & Container Elevation (M3 Roles)

Utilize Material 3 surface containers for soft contrast without heavy drop shadows:
- `surface`: Screen background canvas (`#FFFFFF` in light, `#0F172A` in dark).
- `surfaceContainerLow`: Mildly elevated card backgrounds.
- `surfaceContainer`: Standard card and dialog surfaces.
- `surfaceContainerHigh`: Sub-surface containers (mini metrics, input backgrounds).
- `outlineVariant`: Subtle border outlines (`#E2E8F0` / `#334155`).

## Typography Scale

Centralized Cairo font scale via `AppTypography` with `letterSpacing: 0` for Arabic:
- **Display / Hero**: 24–28 pt, Bold
- **Screen Titles**: 20–22 pt, Bold
- **Section Headers**: 18 pt, SemiBold
- **Card Titles / Body Large**: 16 pt, Medium/SemiBold
- **Standard Body Text**: 14 pt, Regular/Medium
- **Secondary Descriptions**: 12–13 pt, Regular
- **Badges & Micro Labels**: 11–12 pt, Medium
- **Buttons**: 14 pt, SemiBold

## Spacing & Geometry Tokens

- **Spacing Scale**: `4`, `8`, `12`, `16`, `20`, `24`, `32`, `40`
- **Corner Radii**:
  - Small: `8px` (Chips, Badges)
  - Medium: `12px` (Inputs, Buttons, Sub-containers)
  - Large: `16px` (Standard Cards - Default for HR UI)
  - Extra Large: `20–24px` (Dialogs, Bottom Sheets, Header Cards)

## Icon Scale

Standardized Material Icons:
- Inline: `16px`
- Small: `18px`
- Standard / Body: `22px`
- Navigation / Card Leading: `24px`
- Empty State: `40px`
- Hero / Header: `48px`

## RTL / LTR Adaptability

- Automatic directional layout via `EdgeInsetsDirectional`, `AlignmentDirectional`, and `PositionedDirectional`.
- Text alignment using `TextAlign.start` / `TextAlign.end`.
- Chevron and navigation icons dynamically reflect text direction.

## Master Documentation Reference

For exhaustive specs, inspect [`design-system/MASTER.md`](file:///c:/Users/aslam/StudioProjects/hr_employee_system/design-system/MASTER.md).
