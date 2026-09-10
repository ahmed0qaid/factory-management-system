# تقرير نظام التصميم والواجهات (UI Design System Report)

تاريخ التحديث: 4 أغسطس 2026  
المشروع: نظام إدارة الموارد البشرية للموظفين والمسؤولين (HR Employee System)  
إعداد: مهندس Flutter UI/UX الخبير  

---

## 1. ما الذي كان موجودًا من عمل الوكيل السابق؟
- تم فحص وتأكيد وجود المكونات التالية التي أنشأها/طورها الوكيل السابق:
  - `DESIGN.md` المبدئي (دليل التصميم الأولي).
  - مهارة سابقة باسم `.agents/skills/flutter-ui-engineer/SKILL.md`.
  - ملفات Tokens في `lib/theme/` (`app_colors.dart`, `app_component_themes.dart`, `app_radius.dart`, `app_shadows.dart`, `app_spacing.dart`, `app_typography.dart`, `app_theme.dart`).
  - الويدجتس المشتركة في `lib/widgets/common/` (`app_card.dart`, `app_stat_card.dart`, `app_action_card.dart`, `app_status_badge.dart`, `app_section_header.dart`, `app_empty_state.dart`, `app_error_state.dart`, `app_loading_state.dart`).
  - شاشة الموظف الرئيسية المحدثة مبدئياً (`lib/screens/employee/employee_home_screen.dart`).
- **تنويه مهم**: تم الحفاظ بالكامل على العمل السابق وتطويره بدلاً من استبداله أو البدء من الصفر.

---

## 2. ما المستودعات المرجعية الموجودة أو التي تم تنزيلها؟
- المستودع المرجعي للإلهام البصري موجود بالفعل في:
  `design_references/Best-Flutter-UI-Templates`
- تم التأكد من إدراجه في ملف `.gitignore` ضمن مجلد `design_references/`.
- **ملاحظة**: تم استخدامه كمرجع إلهام لتكوين المساحات والتسلسل البصري فقط، دون نسخ أي كود أو مكتبات قديمة أو الاستيراد المباشر منه.

---

## 3. ما Skills الموجودة أو التي تم إنشاؤها؟
1. **المهارات السابقة**:
   - `.agents/skills/flutter-ui-engineer/SKILL.md` (تم الحفاظ عليها).
2. **المهارات الجديدة المخصصة للمشروع**:
   - `.agents/skills/hr-flutter-design-system/SKILL.md`
   - `.claude/skills/hr-flutter-design-system/SKILL.md`
   - **وظيفتها**: تزويد أي وكيل لاحق بمرجع صارم لقواعد التصميم، واستخدام `ColorScheme` و `TextTheme` و Tokens، والالتزام باتجاهات RTL/LTR وحماية منطق الأعمال.

---

## 4. ما قواعد Material 3 التي تم اعتمادها؟
- تفعيل `useMaterial3: true` في `AppTheme`.
- اعتماد `ColorScheme.fromSeed` مع الربط الصريح للمحاور الثلاثة.
- استخدام أدوار الأسطح الحديثة في Material 3:
  - `surface` للسطح الأساسي (`#FFFFFF` في الفاتح / `#0F172A` في الداكن).
  - `surfaceContainerLow` للأسطح المنخفضة (`#F8FAFC`).
  - `surfaceContainer` للبطاقات والقوائم (`#F1F5F9`).
  - `surfaceContainerHigh` للمكونات الفرعية داخل البطاقات.
  - `outlineVariant` للحدود الخفيفة والتقسيم الهادئ (`#E2E8F0` / `#334155`).

---

## 5. ما الألوان الثلاثة المعتمدة؟
1. **Primary Teal (`#0F766E`)**: للأزرار الرئيسية، العنصر النشط، شريط التنقل، والمؤشرات الهامة.
2. **Secondary Slate (`#475569`)**: للنصوص الثانوية، الحدود، الأيقونات المحايدة، البطاقات الثانوية.
3. **Tertiary Amber (`#B45309`)**: للإبراز الثانوي والبطاقات التنبيهية الهامة التي تتطلب انتباهاً (مثل توقفات المصنع ومراجعات الدوام).

---

## 6. متى تستخدم الألوان الدلالية (Semantic Colors)؟
تستخدم الألوان الدلالية **فقط** للتعبير عن حالات فعلية، وتخضع للقواعد التالية:
- **Success (`#16A34A`)**: حالات الحضور، الطلبات المعتمدة، الفواتير المدفوعة.
- **Warning (`#D97706`)**: التأخير، الحالات قيد الاعتماد/المراجعة.
- **Danger (`#DC2626`)**: الغياب، الطلبات المرفوضة، الإجراءات التدميرية.
- **قواعد صارمة**:
  - يمنع استخدامها للزينة أو الخلفيات القوية.
  - يمنع تلوين البطاقات أو السجلات بها بالكامل.
  - يجب مقترنتها دائماً بنص واضح وأيقونة توضيحية.

---

## 7. ما نظام الخطوط والأحجام؟
- الخط المعتمد: Cairo عبر `google_fonts`.
- تم ضبط `letterSpacing: 0` للنص العربي لتفادي مشاكل تقطيع الحروف.
- سلم الخطوط المركزي (`AppTypography`):
  - **عنوان الشاشة**: 22–24 pt (Bold)
  - **عنوان القسم**: 18 pt (SemiBold)
  - **عنوان البطاقة**: 16 pt (Medium/SemiBold)
  - **الرقم الإحصائي**: 22–28 pt (Bold)
  - **النص الرئيسي**: 14 pt (Regular/Medium)
  - **الوصف الثانوي**: 12–13 pt (Regular)
  - **الشارات/البادج**: 11–12 pt (Medium)

---

## 8. ما نظام الأيقونات؟
تم توحيد الأيقونات باستخدام Material Icons ومراعاة الأحجام التليية (`AppIconSizes`):
- Inline: `16px`
- Small: `18px`
- Standard: `22px`
- Navigation / Card Leading: `24px`
- Empty state: `40px`
- Hero / Avatar: `48px`

---

## 9. ما أنواع البطاقات المعتمدة؟
1. **`AppStatCard`**: للإحصائيات والأرقام (Radius: 16, Padding: 12-16, Icon container: 40px). تستخدم ألوان الهوية الثلاثة (`Primary`, `Secondary`, `Tertiary`).
2. **`AppActionCard`**: للإجراءات والتنقل (تحتوي على أيقونة جانبية، عنوان، وصف، وسهم اتجاهي ذكي يتكيف مع RTL/LTR).
3. **`AppStatusCard` / `AppStatusBadge`**: لإظهار حالة الدوام الحالية فقط (تستعين بلون الحالة الدلالي بنسبة شفافة 8% على الخلفية البيضاء لتجنب التلوث البصري).

---

## 10. ما ملفات Design Tokens؟
توجد جميع الملفات مركزيًا تحت `lib/theme/`:
- `app_colors.dart`
- `app_typography.dart`
- `app_spacing.dart`
- `app_radius.dart`
- `app_icon_sizes.dart`
- `app_shadows.dart`
- `app_component_themes.dart`
- `app_theme.dart`

---

## 11. ما الملفات التي تم إنشاؤها؟
1. `design-system/MASTER.md`
2. `design-system/colors.md`
3. `design-system/typography.md`
4. `design-system/spacing.md`
5. `design-system/shapes.md`
6. `design-system/icons.md`
7. `design-system/accessibility.md`
8. `design-system/components/cards.md`
9. `design-system/components/buttons.md`
10. `design-system/components/inputs.md`
11. `design-system/components/badges.md`
12. `design-system/components/navigation.md`
13. `design-system/components/dialogs.md`
14. `.agents/skills/hr-flutter-design-system/SKILL.md`
15. `.claude/skills/hr-flutter-design-system/SKILL.md`
16. `lib/theme/app_icon_sizes.dart`
17. `lib/widgets/common/app_widget_previews.dart`

---

## 12. ما الملفات التي تم تعديلها؟
1. `DESIGN.md` (تحديثه ليتوافق مع نظام M3 والمحاور الثلاثة).
2. `lib/theme/app_colors.dart` (تضمين المحاور الثلاثة وأسطح M3).
3. `lib/theme/app_theme.dart` (ربط `primary`, `secondary`, `tertiary` صراحة في `ColorScheme`).
4. `lib/widgets/common/app_stat_card.dart` (ربط أحجام الأيقونات و M3 container styles).
5. `lib/screens/employee/employee_home_screen.dart` (تطبيق المحاور اللونية الثلاثة وتحديث التنسيق).

---

## 13. ما الشاشة التجريبية التي تم تحسينها؟
- **شاشة الموظف الرئيسية** (`lib/screens/employee/employee_home_screen.dart`).
- تم التأكد من تطبيق الهوية البصرية الجديدة عليها بدون المساس بأي من بيانات الموظف أو الاستدعاءات أو الحسابات الخاصة بالسلف والإجازات والجزاءات.

---

## 14. ما التحسينات السابقة التي تم الحفاظ عليها؟
- الحفاظ على كروت الإحصائيات الاستجابية (`_ResponsiveGrid`).
- الحفاظ على الترويسة التعريفية بالموظف والرقابة على القيم الفارغة.
- الحفاظ على ربط خدمات `EmployeeService` و `AppwriteService`.
- الحفاظ على حالة التحميل `AppLoadingState` وحالة الخطأ `AppErrorState` وحالة الفراغ `AppEmptyState`.

---

## 15. نتيجة `flutter analyze` قبل وبعد
- **قبل التعديل**:
  - إجمالي التحذيرات في كامل المستودع: 764 تحذير/lints قديمة (معظمها في شاشات الأدمن والسكريبتات والتجارب).
  - التنبيهات الخاصة بـ `lib/`: 58 تنبيه (أقواس `if` و deprecations سابقة).
- **بعد التعديل**:
  - عند تشغيل `flutter analyze lib/theme lib/widgets/common lib/screens/employee/employee_home_screen.dart`:
    `No issues found!` (0 أخطاء و 0 تحذيرات في جميع ملفات Design System والشاشة المعدلة).

---

## 16. حالات RTL/LTR التي تم اختبارها
- **العربية (RTL)**:
  - محاذاة `TextAlign.start` تبدأ من اليمين بشكل طبيعي.
  - الأسهم التوجيهية في `AppActionCard` تعكس الاتجاه تلقائياً.
  - مسافات النص العربي محددة بـ `letterSpacing: 0` لمنع تشوه الكلمات.
- **الإنجليزية (LTR)**:
  - المحاذاة تستجيب لـ Directionality وتدعم العرض من اليسار لليمين.

---

## 17. المشكلات المتبقية
- توجد بعض التحذيرات والـ deprecations القديمة في شاشات الإدارة (Admin screens) والسكريبتات (مثل `curly_braces_in_flow_control_structures` واستخدام `withOpacity` بدلاً من `withValues`) خارج نطاق شاشة الموظف التجارية الحالية.

---

## 18. الخطة المقترحة لتعميم النظام على بقية الشاشات (دون تنفيذها الآن)
1. **الخطوة الأولى**: تعميم المكونات المشتركة على شاشات الموظف التابعة (`attendance_timeline_screen.dart`, `advances_screen.dart`, `leave_requests_screen.dart`, `penalties_screen.dart`, `payroll_screen.dart`).
2. **الخطوة الثانية**: توحيد حقول المدخلات والأزرار في شاشات المصادقة (`login_screen.dart`, `force_password_change_screen.dart`).
3. **الخطوة الثالثة**: تعميم النظام على شاشات لوحة تحكم المسؤول (Admin Dashboard) وإلغاء أي استخدام متبقي لألوان أو أبعاد ثابتة يدويًا inside screens.
