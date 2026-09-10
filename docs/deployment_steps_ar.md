# خطوات النشر

## 1. Supabase

- أنشئ مشروع Supabase.
- نفّذ `schema.sql`.
- عدّل ونفّذ `seed.sql`.
- أنشئ bucket باسم `employee-files`.
- انشر Edge Function:

```bash
supabase functions deploy create-employee
```

## 2. إعداد secrets للـ Edge Function

داخل Supabase Dashboard أو CLI:

```bash
supabase secrets set SUPABASE_URL=...
supabase secrets set SUPABASE_ANON_KEY=...
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
```

## 3. Flutter Mobile

```bash
flutter pub get
flutter run
```

لإصدار Android:

```bash
flutter build apk --release
```

أو للنشر على Google Play:

```bash
flutter build appbundle --release
```

## 4. Flutter Web Admin

```bash
flutter build web --release
```

ثم ارفع `build/web` على Netlify.

## 5. متغيرات Netlify

إذا قررت تمرير القيم وقت البناء:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## 6. فحص الأمان قبل النشر

- تأكد أن RLS مفعّل.
- تأكد أن الموظف لا يرى بيانات غيره.
- تأكد أن service_role غير موجود في Flutter.
- جرّب حساب موظف وحساب HR وحساب Admin.
- راجع Storage policies قبل رفع ملفات حقيقية.
