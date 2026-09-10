# تحديث المشروع إلى Appwrite TablesDB

هذا التحديث يستبدل استخدام واجهة Appwrite القديمة:

- `Databases.listDocuments`
- `Databases.getDocument`
- `Databases.createDocument`
- `Databases.updateDocument`

بالواجهة الجديدة الموصى بها في Appwrite:

- `TablesDB.listRows`
- `TablesDB.getRow`
- `TablesDB.createRow`
- `TablesDB.updateRow`

## الملفات التي تم تعديلها

- `flutter_app/lib/services/appwrite_service.dart`
- `flutter_app/lib/services/auth_service.dart`
- `flutter_app/lib/services/employee_service.dart`
- `flutter_app/lib/services/admin_service.dart`
- `flutter_app/lib/config/constants.dart`
- `appwrite/functions/create-employee/index.js`

## أهم التغييرات في Flutter

```dart
// قبل
Databases databases = Databases(client);

// بعد
TablesDB tablesDB = TablesDB(client);
```

```dart
// قبل
final data = await databases.listDocuments(
  databaseId: databaseId,
  collectionId: 'profiles',
);

// بعد
final data = await tablesDB.listRows(
  databaseId: databaseId,
  tableId: 'profiles',
);
```

```dart
// قبل
return data.documents.map(...);

// بعد
return data.rows.map(...);
```

```dart
// قبل
await databases.updateDocument(
  databaseId: databaseId,
  collectionId: 'profiles',
  documentId: userId,
  data: {...},
);

// بعد
await tablesDB.updateRow(
  databaseId: databaseId,
  tableId: 'profiles',
  rowId: userId,
  data: {...},
);
```

## هل نعيد إنشاء قاعدة البيانات؟

لا. إذا كنت قد أنشأت الجداول/الكولكشنز سابقًا بنفس IDs، فيمكنك استخدام نفس IDs كـ `tableId`.

## ملاحظات مهمة

- كلمة `collectionId` أصبحت `tableId`.
- كلمة `documentId` أصبحت `rowId`.
- `DocumentList.documents` أصبحت `RowList.rows`.
- `models.Document` أصبحت `models.Row`.
- نفس نظام الصلاحيات Permissions يعمل مع Rows.
- لا تضع API Key داخل Flutter؛ يبقى API Key داخل Appwrite Function فقط.

## الاختبار بعد التحديث

نفذ الأوامر التالية:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run -d chrome
```

بعد ذلك جرّب:

1. تسجيل دخول HR.
2. ظهور لوحة الإدارة.
3. إنشاء موظف جديد من الإدارة.
4. دخول الموظف بكلمة المرور المؤقتة.
5. إجبار الموظف على تغيير كلمة المرور.
6. عرض بيانات الموظف والراتب والمكافأة والمستحق الشهري.
7. طلب سلفة من الموظف.
