# Colors & Material 3 Color Roles

## Overview

The app uses one deep-teal brand seed and derives its structural palette with `ColorScheme.fromSeed`. Screen code must consume semantic Material 3 roles rather than copying fixed hex colors.

---

## 1. Brand Seed

| Role | Seed | Usage | Code |
| :--- | :--- | :--- | :--- |
| **Primary identity** | `#0F766E` | High-emphasis action, selected state, focus, small identity accents | `AppColors.primary` as seed → `colorScheme.primary*` |

`secondary` and `tertiary` are generated tonal roles. They are available when Material components need those roles, but should not become arbitrary category colors for cards.

---

## 2. Structural Material 3 Roles

Use the active `ColorScheme` so Light and Dark modes resolve correctly:

- `surface`: page canvas.
- `surfaceContainerLowest`: main neutral card.
- `surfaceContainerLow`: slightly separated surface.
- `surfaceContainer`: nested/metric surface.
- `surfaceContainerHigh` / `surfaceContainerHighest`: stronger neutral separation and disabled states.
- `onSurface`: primary content.
- `onSurfaceVariant`: secondary/meta content and neutral icons.
- `outlineVariant`: subtle borders and dividers.
- `outline`: stronger outline when necessary.
- `primaryContainer` / `onPrimaryContainer`: selected indicators and soft brand emphasis.

Do not assume surface is literal white or dark surface is one fixed navy value.

---

## 3. Semantic State Roles

### Success

Use `context.semanticColors.success` and container roles only for real success such as:

- `present`
- `approved`
- `paid`
- `completed`
- successful operations

### Warning

Use `context.semanticColors.warning` and container roles for:

- `late`
- `pending`
- `needs_review`
- `incomplete`
- attention without failure

### Error / Danger

Use Material roles:

- `colorScheme.error`
- `colorScheme.onError`
- `colorScheme.errorContainer`
- `colorScheme.onErrorContainer`

for:

- `absent` when represented as a negative state
- `rejected`
- `cancelled`
- validation errors
- failed operations
- destructive actions

**Constraint:** semantic colors are never decorative category colors. Every status also needs a label/icon; color alone is insufficient.

---

## 4. Common Anti-patterns

Do not use:

```dart
color: Colors.white
color: Colors.grey
color: AppColors.primary // on every card
```

for structural styling in production screens.

Prefer:

```dart
final scheme = Theme.of(context).colorScheme;

color: scheme.surfaceContainerLowest
borderColor: scheme.outlineVariant
textColor: scheme.onSurface
metaColor: scheme.onSurfaceVariant
```

For status:

```dart
final semantic = context.semanticColors;

successColor: semantic.success
warningColor: semantic.warning
errorColor: scheme.error
```

---

## 5. Theme Modes

The same role-based code must work in:

- System
- Light
- Dark

Theme mode is owned by `AppThemeController` and selected in Settings.
