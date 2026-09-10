# نظام الموارد البشرية — Flutter + Appwrite Cloud + TablesDB

هذه الحزمة تمثل الأساس التنفيذي للنسخة الأولى من نظام الموارد البشرية بعد التحديث إلى Appwrite TablesDB.

## البنية الحالية

- Flutter Mobile للموظف والإدارة.
- Flutter Web للوحة الإدارة.
- Appwrite Auth لتسجيل الدخول.
- Appwrite TablesDB لحفظ بيانات النظام كـ Tables و Rows.
- Appwrite Storage لحفظ صور الموظفين والمستندات.
- Appwrite Functions لإنشاء حسابات الموظفين وتنفيذ العمليات الحساسة.

## الدخول

لا يوجد تسجيل ذاتي للموظف. الموارد البشرية تنشئ حساب الموظف.

يدخل الموظف برقم الموظف، ويحوّله التطبيق داخليًا إلى بريد تقني:

`EMP001` → `emp001@hr.local`

في أول دخول يجب تغيير كلمة المرور المؤقتة قبل فتح النظام.

## الأدوار

- `hr_admin` الموارد البشرية: صلاحيات مطلقة.
- `general_manager` المدير العام: متابعة واعتماد ومراجعة عامة.
- `financial_manager` المدير المالي: رواتب وسلف وتقارير مالية.
- `employee` الموظف: واجهات الموظف فقط.

## أهم الجداول Tables

- `profiles`
- `attendance_records`
- `penalties`
- `payroll_records`
- `advances`
- `announcements`

راجع المخطط:

`appwrite/tables_schema.json`

## تحديث TablesDB

تم استبدال الواجهات القديمة:

- `Databases.listDocuments`
- `Databases.getDocument`
- `Databases.createDocument`
- `Databases.updateDocument`

بالواجهات الجديدة:

- `TablesDB.listRows`
- `TablesDB.getRow`
- `TablesDB.createRow`
- `TablesDB.updateRow`

راجع:

`docs/tablesdb_update_ar.md`

## التشغيل السريع

1. أنشئ مشروعًا في Appwrite Cloud.
2. أضف Android Platform و Web Platform.
3. أنشئ Database ID: `hr`.
4. أنشئ Tables حسب الملف: `appwrite/tables_schema.json`.
5. أنشئ Bucket ID: `employee_files`.
6. أنشئ Team للشركة وأضف أول مستخدم موارد بشرية.
7. عدّل ملف: `flutter_app/.env`.
8. شغّل:

```bash
cd flutter_app
flutter create --platforms=android,web --org com.yourcompany .
flutter pub get
flutter analyze
flutter run -d chrome
```

## مهم أمنيًا

لا تضع API Key داخل Flutter. أي API Key يجب أن يبقى داخل Appwrite Function فقط.
