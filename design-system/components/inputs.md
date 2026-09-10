# Component Specification: Inputs & Forms

- **Input Decoration**: Centralized via `AppComponentThemes.input`.
- **Border**: Radius `12px`, border color `outlineVariant` when idle, `primary` when focused.
- **Background**: Soft filled background (`surfaceContainerHigh` or `#F8FAFC`).
- **Text Alignment**: `TextAlign.start` respecting active Locale (`ar` / `en`).
- **Error State**: Displays red text underneath with subtle red outline border (`AppColors.danger`).
