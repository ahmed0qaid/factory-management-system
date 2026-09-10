import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app.dart';
import 'services/appwrite_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env', isOptional: true);

  const endpointFromDefine = String.fromEnvironment('APPWRITE_ENDPOINT');
  const projectFromDefine = String.fromEnvironment('APPWRITE_PROJECT_ID');
  const databaseFromDefine = String.fromEnvironment('APPWRITE_DATABASE_ID');
  const functionFromDefine = String.fromEnvironment(
    'APPWRITE_CREATE_EMPLOYEE_FUNCTION_ID',
  );

  final endpoint = endpointFromDefine.isNotEmpty
      ? endpointFromDefine
      : dotenv.env['APPWRITE_ENDPOINT'];
  final projectId = projectFromDefine.isNotEmpty
      ? projectFromDefine
      : dotenv.env['APPWRITE_PROJECT_ID'];
  final databaseId = databaseFromDefine.isNotEmpty
      ? databaseFromDefine
      : (dotenv.env['APPWRITE_DATABASE_ID'] ?? 'hr');
  final createEmployeeFunctionId = functionFromDefine.isNotEmpty
      ? functionFromDefine
      : (dotenv.env['APPWRITE_CREATE_EMPLOYEE_FUNCTION_ID'] ??
            'create_employee');

  if (endpoint == null ||
      endpoint.isEmpty ||
      projectId == null ||
      projectId.isEmpty) {
    runApp(const MissingConfigApp());
    return;
  }

  await AppwriteService.init(
    endpoint: endpoint,
    projectId: projectId,
    databaseId: databaseId,
    createEmployeeFunctionId: createEmployeeFunctionId,
  );

  runApp(const HrApp());
}

class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Cairo',
      ),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'لم يتم ضبط بيانات Appwrite. انسخ .env.example إلى .env وضع APPWRITE_ENDPOINT و APPWRITE_PROJECT_ID.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
