# Colors & ColorScheme Roles

## Color System Overview

The HR Employee System uses a strict Material 3 palette with 3 core brand axes and 3 semantic status colors.

---

## 1. Brand Axes

| Role | Color Hex | Usage | Code Token |
| :--- | :--- | :--- | :--- |
| **Primary** | `#0F766E` | Main actions, active tab, header background, key brand highlights | `AppColors.primary` / `colorScheme.primary` |
| **Secondary** | `#475569` | Subtitles, neutral icons, borders, inactive indicators, secondary actions | `AppColors.secondary` / `colorScheme.secondary` |
| **Tertiary** | `#B45309` | Warm highlights, attention banners, non-error notifications | `AppColors.tertiary` / `colorScheme.tertiary` |

---

## 2. Material 3 Surface Containers

To avoid harsh shadows and ensure soft layer contrast:

- `surface`: Base background canvas (`#FFFFFF` in light, `#0F172A` in dark)
- `surfaceContainerLow`: Low-elevation card surfaces (`#F8FAFC` in light)
- `surfaceContainer`: Standard cards and bottom sheets
- `surfaceContainerHigh`: Sub-containers (e.g. mini metric tiles inside cards)
- `outlineVariant`: Subtle border divider lines (`#E2E8F0` / `#334155`)

---

## 3. Semantic Colors (Strict State Usage)

- **Success (`#16A34A`)**: Used ONLY for `present`, `approved`, `paid`, `completed`.
- **Warning (`#D97706`)**: Used ONLY for `late`, `pending`, `needs_review`.
- **Danger (`#DC2626`)**: Used ONLY for `absent`, `rejected`, `cancelled`, destructive actions.

*Constraint: Never use semantic colors for decorative card tiles or general icons.*
