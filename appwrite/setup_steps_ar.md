# خطوات إعداد Appwrite Cloud — نسخة TablesDB

## 1) إنشاء Project

افتح:

`https://cloud.appwrite.io/`

ثم أنشئ مشروعًا جديدًا باسم مثل:

`HR System`

انسخ:

- Project ID
- API Endpoint

## 2) إضافة Platforms

من:

`Project > Platforms`

أضف:

### Android

ضع Package Name مثل:

`com.yourcompany.hr_employee_system`

### Web

للتجربة المحلية أضف:

`localhost`

وللنشر أضف دومين موقع الإدارة لاحقًا.

## 3) إنشاء Database

من:

`Databases / TablesDB`

أنشئ Database بالمعرف:

`hr`

## 4) إنشاء Tables

أنشئ الجداول الموجودة في:

`appwrite/tables_schema.json`

أهم الجداول:

- `profiles`
- `attendance_records`
- `penalties`
- `payroll_records`
- `advances`
- `announcements`

ملاحظة: Appwrite كان يستخدم سابقًا Collections/Documents، أما الآن فالتسمية الجديدة هي Tables/Rows. يمكن أن تبقى IDs نفسها مثل `profiles` و `attendance_records`.

## 5) إنشاء Storage Bucket

من Storage أنشئ Bucket ID:

`employee_files`

## 6) إنشاء Team للشركة

من:

`Auth > Teams`

أنشئ Team للشركة، واستخدم Team ID كقيمة `company_id` داخل جدول `profiles`.

أضف أول مسؤول موارد بشرية لهذا الفريق بدور:

`hr_admin`

## 7) إنشاء أول مستخدم موارد بشرية

من:

`Auth > Users`

أنشئ مستخدمًا، مثال:

- Email: `hr001@hr.local`
- Password: `12345678`

انسخ User ID.

## 8) إنشاء Row في profiles

افتح جدول `profiles` وأنشئ Row جديدًا.

اجعل Row ID مساويًا لـ User ID نفسه.

مثال بيانات:

```json
{
  "company_id": "TEAM_ID_HERE",
  "employee_number": "HR001",
  "full_name": "مسؤول الموارد البشرية",
  "role": "hr_admin",
  "department_name": "الموارد البشرية",
  "job_title_name": "مسؤول موارد بشرية",
  "base_salary": 0,
  "monthly_bonus": 0,
  "active": true,
  "must_change_password": false
}
```

الصلاحيات المقترحة للـRow:

- Read: المستخدم نفسه
- Update: المستخدم نفسه
- Read/Update/Delete: Team مع role `hr_admin`

## 9) إعداد Flutter

عدّل:

`flutter_app/.env`

```env
APPWRITE_ENDPOINT=https://cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=ضع_Project_ID
APPWRITE_DATABASE_ID=hr
APPWRITE_CREATE_EMPLOYEE_FUNCTION_ID=create_employee
```

## 10) نشر Function إنشاء الموظف

من:

`Functions > Create Function`

اجعل Function ID:

`create_employee`

ارفع الملفات من:

`appwrite/functions/create-employee`

ضع المتغيرات السرية:

```env
APPWRITE_ENDPOINT=https://cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=ضع_Project_ID
APPWRITE_API_KEY=مفتاح سيرفر بصلاحيات Users + TablesDB
APPWRITE_DATABASE_ID=hr
```

## 11) الاختبار

```bash
cd flutter_app
flutter clean
flutter pub get
flutter analyze
flutter run -d chrome
```

ثم جرّب:

1. دخول HR برقم `HR001`.
2. إضافة موظف جديد من الإدارة.
3. دخول الموظف بكلمة مرور مؤقتة.
4. تغيير كلمة المرور في أول دخول.
5. عرض بيانات الموظف والراتب والمكافأة والمستحق الشهري.
