import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hr_employee_system/main.dart';

void main() {
  testWidgets('MissingConfigApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MissingConfigApp());

    // Verify that the missing config message is displayed.
    expect(find.byType(Text), findsOneWidget);
    expect(
      find.text(
        'لم يتم ضبط بيانات Appwrite. انسخ .env.example إلى .env وضع APPWRITE_ENDPOINT و APPWRITE_PROJECT_ID.',
      ),
      findsOneWidget,
    );
  });
}
