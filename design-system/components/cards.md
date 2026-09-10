# Component Specification: Cards

The system defines 3 canonical card types. Do not invent new card classes unless explicitly justified.

---

## 1. `AppStatCard` (KPI & Metrics)
- **Purpose**: Display numerical metrics, advance balances, day counts.
- **Radius**: `16px` (`AppRadius.lg`)
- **Padding**: `12px` or `16px` (`AppSpacing.sm` / `md`)
- **Border**: `outlineVariant`
- **Icon Container**: `34–40px` with 8% opacity background
- **Colors**: Uses Primary, Secondary, or Tertiary identity colors. NO semantic colors unless explicitly representing an overall attendance status metric.

---

## 2. `AppActionCard` (Navigation & Actions)
- **Purpose**: Tapable list items leading to detail screens.
- **Layout**: Leading Icon (`22px`) + Title/Subtitle + Dynamic Directional Chevron.
- **Radius**: `16px`
- **Interactive Feedback**: Material ink splash or hover state.

---

## 3. `AppStatusCard` / Hero Card
- **Purpose**: Display current real-time attendance status.
- **Color**: Semantic status color (`AppColors.success`, `warning`, `danger`) used only on status badge and container tint (8% opacity), preserving white/neutral card body.
