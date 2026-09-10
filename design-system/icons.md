# Icons & Micro-Interactions

## Icon Sizes (`AppIconSizes`)

- **Inline (`16px`)**: Embedded alongside inline text labels.
- **Small (`18px`)**: Sub-metrics, table row icons.
- **Standard (`22px`)**: Action card leadings, button icons.
- **Navigation (`24px`)**: Navigation bar items, card primary icons.
- **Empty State (`40px`)**: Empty/error state illustrations.
- **Hero (`48px`)**: Header avatars and primary card status icons.

---

## Directionality Rules

- Use `Icons.chevron_left` / `Icons.chevron_right` dynamically depending on `Directionality.of(context)`.
- Direction-sensitive icons (e.g. forward arrow, drawer toggle) mirror automatically in RTL.
