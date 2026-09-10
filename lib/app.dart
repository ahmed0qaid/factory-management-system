import 'package:appwrite/appwrite.dart' hide Locale;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/auth/login_screen.dart';
import 'screens/employee/employee_shell.dart';
import 'services/appwrite_service.dart';
import 'theme/app_theme.dart';

class HrApp extends StatelessWidget {
  const HrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نظام الموارد البشرية',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AppwriteService.account.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is AppwriteException) return const LoginScreen();
          return Scaffold(body: Center(child: Text('خطأ في الاتصال: $error')));
        }
        return const EmployeeShell();
      },
    );
  }
}
