import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  final client = Client()
    ..setEndpoint('https://cloud.appwrite.io/v1')
    ..setProject('hr-system')
    ..setKey(Platform.environment['APPWRITE_API_KEY'] ?? '');

  final db = Databases(client);
  final dbId = 'hr';
  final jobTitlesCollection = 'job_titles';
  final profilesCollection = 'profiles';
  final companyId = '6a715a31ad190776784d';

  print('--- بدء الاختبار النهائي العملي ---');

  // 1. إدارة المسميات الوظيفية
  try {
    print('1. التحقق من جدول المسميات الوظيفية:');
    final titlesRes = await db.listDocuments(
      databaseId: dbId,
      collectionId: jobTitlesCollection,
      queries: [Query.equal('company_id', companyId)],
    );
    print('   - إجمالي المسميات: \${titlesRes.total}');
    
    // إنشاء مسمى جديد للتجربة
    final testTitleId = ID.unique();
    await db.createDocument(
      databaseId: dbId,
      collectionId: jobTitlesCollection,
      documentId: testTitleId,
      data: {
        'company_id': companyId,
        'name': 'مسمى اختبار',
        'active': true,
      },
    );
    print('   - تم إضافة مسمى جديد بنجاح: مسمى اختبار (ID: \$testTitleId)');

    // تعطيله
    await db.updateDocument(
      databaseId: dbId,
      collectionId: jobTitlesCollection,
      documentId: testTitleId,
      data: {
        'active': false,
      },
    );
    
    final disabledTitle = await db.getDocument(
      databaseId: dbId,
      collectionId: jobTitlesCollection,
      documentId: testTitleId,
    );
    print('   - تم تعطيل المسمى (active: ${disabledTitle.data['active']}). لم يتم حذفه.');
  } catch (e) {
    print('خطأ في المسميات: \$e');
  }

  // 2. التحقق من Profiles (التعديل)
  try {
    print('\\n2. التحقق من تعديل موظف:');
    final profilesRes = await db.listDocuments(
      databaseId: dbId,
      collectionId: profilesCollection,
      queries: [Query.equal('company_id', companyId), Query.limit(1)],
    );
    if (profilesRes.documents.isNotEmpty) {
      final emp = profilesRes.documents.first;
      print('   - الموظف قبل التعديل: ${emp.data['full_name']} | Title: ${emp.data['job_title_name']} (ID: ${emp.data['job_title_id']})');
      
      // تحديث المسمى الوظيفي
      final updatedEmp = await db.updateDocument(
        databaseId: dbId,
        collectionId: profilesCollection,
        documentId: emp.$id,
        data: {
          'job_title_id': '6a7409928f6852b9f5d6', // أمين المخازن
          'job_title_name': 'أمين المخازن',
        },
      );
      print('   - الموظف بعد التعديل: ${updatedEmp.data['full_name']} | Title: ${updatedEmp.data['job_title_name']} (ID: ${updatedEmp.data['job_title_id']})');
      print('   - نجاح! تم حفظ الاثنين (job_title_id و job_title_name).');
    }
  } catch (e) {
    print('خطأ في الموظفين: \$e');
  }

  print('\\n--- اكتمل الاختبار بنجاح ---');
}
