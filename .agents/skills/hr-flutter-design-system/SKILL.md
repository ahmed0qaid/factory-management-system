# HR Flutter Design System Skill

Use this skill for any UI/UX or design system work inside this HR employee system codebase.

---

## Mandated Agent Workflow

1. **Read Core Design Specs First**:
   - Read [`DESIGN.md`](file:///c:/Users/aslam/StudioProjects/hr_employee_system/DESIGN.md)
   - Read [`design-system/MASTER.md`](file:///c:/Users/aslam/StudioProjects/hr_employee_system/design-system/MASTER.md)
   - Read the component spec file related to your task under `design-system/components/`.

2. **Inspect Existing Code**:
   - Inspect `lib/theme/` and existing shared widgets in `lib/widgets/common/`.
   - Never invent arbitrary colors (`Colors.blue`), font sizes (`fontSize: 17`), padding (`EdgeInsets.all(13)`), or corner radius (`BorderRadius.circular(11)`) inside screen files.

3. **Use Centralized Tokens & Roles**:
   - Use `ColorScheme` roles (`primary`, `secondary`, `tertiary`, `surfaceContainer`, `outlineVariant`).
   - Use `TextTheme` roles (`titleMedium`, `bodyMedium`, `labelMedium`, etc.).
   - Use `AppSpacing`, `AppRadius`, `AppIconSizes`, and `AppShadows`.
   - Use approved shared widgets (`AppStatCard`, `AppActionCard`, `AppStatusBadge`, `AppCard`, `AppSectionHeader`).

4. **Strict Rules**:
   - **Semantic Colors**: Use `AppColors.success`, `warning`, `danger` ONLY for real attendance/leave/payroll status. Never for decorative background tiles or quick action icons.
   - **RTL / LTR**: Use `EdgeInsetsDirectional`, `AlignmentDirectional`, and directional icons so layouts seamlessly adapt to both Arabic and English locales.
   - **Business Logic Protection**: NEVER modify controllers, services, models, Appwrite queries, authentication, or routing logic.
   - **Verification**: Never consider editing `app_colors.dart` alone a completion; verify that visible UI widgets use the design tokens.
   - **Commands**: Always execute `dart format .` and `flutter analyze lib/` after making changes.
