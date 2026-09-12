import 'package:appwrite/appwrite.dart' hide Locale;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/auth/login_screen.dart';
import 'screens/employee/employee_shell.dart';
import 'services/appwrite_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_controller.dart';

class HrApp extends StatelessWidget {
  const HrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'نظام إدارة موظفي المصنع',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final dark = theme.brightness == Brightness.dark;

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    dark ? Brightness.light : Brightness.dark,
                statusBarBrightness:
                    dark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: scheme.surface,
                systemNavigationBarIconBrightness:
                    dark ? Brightness.light : Brightness.dark,
                systemNavigationBarDividerColor: scheme.outlineVariant,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthGate(),
        );
      },
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
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'تعذر الاتصال بالخدمة: $error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return const EmployeeShell();
      },
    );
  }
}
