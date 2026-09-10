# استخدام Appwrite بدل Supabase

في هذه النسخة تم اعتماد Appwrite Cloud بدل Supabase.

## المقارنة

| الجزء | Supabase | Appwrite Cloud |
|---|---|---|
| تسجيل الدخول | Supabase Auth | Appwrite Auth |
| قاعدة البيانات | PostgreSQL SQL Tables | Appwrite TablesDB: Tables/Rows |
| الملفات | Supabase Storage | Appwrite Storage |
| العمليات الحساسة | Edge Functions | Appwrite Functions |
| الصلاحيات | RLS Policies | Permissions + Teams + Roles |
| تطبيق Flutter | supabase_flutter | appwrite |

## ماذا يعني TablesDB؟

بدل المصطلحات القديمة:

- Collections
- Documents
- Attributes

أصبحنا نستخدم:

- Tables
- Rows
- Columns

وفي الكود:

```dart
TablesDB tablesDB = TablesDB(client);
```

ثم:

```dart
tablesDB.listRows(...)
tablesDB.createRow(...)
tablesDB.updateRow(...)
```

## قرار المشروع

المشروع الحالي لا يحتاج Backend FastAPI أو Neon في البداية. Appwrite Cloud يكفي كباكند للنسخة الأولى:

- Auth
- TablesDB
- Storage
- Functions
- Sites اختيارية لموقع الإدارة
