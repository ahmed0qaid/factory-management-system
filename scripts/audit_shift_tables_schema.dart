import 'dart:convert';
import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  final endpoint = 'https://fra.cloud.appwrite.io/v1';
  final projectId = '6a6a49d1000884049205';
  final databaseId = 'hr';
  final apiKey = 'standard_8831478838d66625e099e541665906fd006bd08bf2a3c096a2f8f9309808423ce8f9d92445107edbb603f6db41f75886a3e090cb5b8c1e38a8958ddf55527c53742cdb09a5ece5f901fac546e1540f37eefbe1dcfc4eb8e3b629bd485757dcd2c9eef58ca287bb38ee33c5538cac13c601c1a292125b91dd354467c72251ed93';

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final db = Databases(client);

  final tables = [
    'employee_shift_assignments',
    'employee_work_schedules',
    'shifts',
  ];

  for (final tableId in tables) {
    print('');
    print('=' * 60);
    print('TABLE: $tableId');
    print('=' * 60);

    try {
      final attrs = await db.listAttributes(
        databaseId: databaseId,
        collectionId: tableId,
      );

      print('Total attributes: ${attrs.total}');
      print('');
      print('${'FIELD'.padRight(30)} ${'TYPE'.padRight(15)} ${'REQUIRED'.padRight(10)} ${'DEFAULT'.padRight(20)} SIZE/STATUS');
      print('-' * 110);

      for (final attr in attrs.attributes) {
        // attr is a Map<String, dynamic>
        final map = attr as Map<String, dynamic>;
        final key = map['key'] ?? '?';
        final type = map['type'] ?? '?';
        final required = map['required'] ?? false;
        final defaultVal = map['\$default'] ?? map['default'] ?? '-';
        final size = map['size'] ?? '-';
        final status = map['status'] ?? '-';

        print('${key.toString().padRight(30)} ${type.toString().padRight(15)} ${required.toString().padRight(10)} ${defaultVal.toString().padRight(20)} size=$size status=$status');
      }

      // Also print raw JSON for debugging
      print('');
      print('--- RAW JSON ---');
      for (final attr in attrs.attributes) {
        final map = attr as Map<String, dynamic>;
        print(jsonEncode(map));
      }
    } catch (e, st) {
      print('ERROR reading table $tableId: $e');
      print('Stack: $st');
    }
  }

  print('');
  print('=' * 60);
  print('AUDIT COMPLETE');
  print('=' * 60);
}
