# HR Flutter Design System Skill

Use this skill for any UI/UX or design-system work inside this HR employee system codebase.

---

## Mandated Agent Workflow

1. **Read Core Design Specs First**:
   - Read [`DESIGN.md`](../../../DESIGN.md).
   - Read [`docs/THEME_SYSTEM.md`](../../../docs/THEME_SYSTEM.md).
   - Read [`design-system/MASTER.md`](../../../design-system/MASTER.md).
   - Read the component spec related to the task under `design-system/components/` when present.

2. **Inspect Existing Code**:
   - Inspect `lib/theme/` and shared widgets in `lib/widgets/common/` before styling a screen.
   - Prefer fixing or extending the shared component/theme rather than repeating styles in individual screens.
   - Never invent arbitrary colors (`Colors.blue`), font sizes, padding, radii, or shadows inside screen files when a token or theme role already exists.

3. **Use Centralized Theme Roles**:
   - Structural colors must come from `Theme.of(context).colorScheme`.
   - Use `primary` only for brand/high-emphasis actions and selected states.
   - Use `surface`, `surfaceContainer*`, `outlineVariant`, `onSurface`, and `onSurfaceVariant` for layout structure and hierarchy.
   - Success and warning states must use `context.semanticColors` from `app_semantic_colors.dart`.
   - Errors, destructive actions, rejection, and invalid states must use `colorScheme.error` / `errorContainer` roles.
   - `AppColors` is a compatibility layer for legacy code, not the default source for new screen styling.
   - Use `TextTheme` roles (`titleMedium`, `bodyMedium`, `labelMedium`, etc.).
   - Use `AppSpacing`, `AppRadius`, `AppIconSizes`, and `AppShadows`.
   - Prefer approved shared widgets (`AppStatCard`, `AppActionCard`, `AppStatusBadge`, `AppStatusPill`, `AppCard`, `AppSectionHeader`).

4. **Color Discipline**:
   - Do not color entire cards just to distinguish modules. Keep structural surfaces neutral.
   - Use color sparingly on icons, selected controls, primary actions, and real semantic states.
   - Green = success/approved/paid/completed only.
   - Amber = pending/late/review/attention only.
   - Red = error/rejected/absent/destructive only.
   - Never communicate status with color alone; pair it with text and/or an icon.
   - Never hardcode `Colors.white`, `Colors.black`, `Colors.grey`, or fixed light backgrounds in production widgets unless the value is intentionally independent of theme and justified.

5. **Light/Dark/System**:
   - Every visible production widget must remain readable in both `ThemeMode.light` and `ThemeMode.dark`.
   - Theme selection is owned by `AppThemeController`; do not create another theme preference path.
   - When custom legacy accent colors must be accepted by a reusable component, adapt them for brightness/contrast instead of assuming a light surface.

6. **RTL / LTR**:
   - Use `EdgeInsetsDirectional`, `AlignmentDirectional`, and directional icons when direction matters.
   - Do not encode Arabic-only left/right assumptions into reusable widgets.

7. **Business Logic Protection**:
   - Design-system changes must not alter controllers, Appwrite queries, authentication, payroll calculations, permissions, or routing behavior unless the task explicitly requires it.

8. **Verification**:
   - Never consider editing `app_colors.dart` alone a completed theme change; verify that visible widgets consume theme roles.
   - Run `dart format .` and `flutter analyze lib/` after changes.
   - Visually review the main employee tabs, admin dashboard, dialogs, bottom sheets, reports, and settings in both light and dark themes.
