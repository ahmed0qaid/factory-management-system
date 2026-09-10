# Spacing & Layout Tokens

## Spacing Scale

All margins, paddings, and gap sizes MUST pull from `AppSpacing`:

| Token | Pixels | Usage |
| :--- | :--- | :--- |
| `AppSpacing.xxs` | 4px | Micro padding between text line & subtitle |
| `AppSpacing.xs` | 8px | Gap between icon & label, chip padding |
| `AppSpacing.sm` | 12px | Gap between cards in a list, compact card padding |
| `AppSpacing.md` | 16px | Standard card padding, grid spacing |
| `AppSpacing.lg` | 20px | Hero card padding, major section gaps |
| `AppSpacing.xl` | 24px | Screen section margins |
| `AppSpacing.xxl` | 32px | Screen header top margin |
| `AppSpacing.giant` | 40px | Empty state top padding |

---

## Screen Layout Boundaries

- `screenHorizontal`: `16px` (Mobile) / `24px` (Tablet)
- `screenBottom`: `24px` padding to prevent navigation bar overlap
