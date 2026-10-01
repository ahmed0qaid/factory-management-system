import 'package:appwrite/appwrite.dart' hide Locale;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/auth/login_screen.dart';
import 'screens/employee/employee_shell.dart';
import 'services/appwrite_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_controller.dart';
import 'widgets/common/app_error_state.dart';
import 'widgets/common/app_loading_state.dart';

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
                statusBarIconBrightness: dark
                    ? Brightness.light
                    : Brightness.dark,
                statusBarBrightness: dark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: scheme.surface,
                systemNavigationBarIconBrightness: dark
                    ? Brightness.light
                    : Brightness.dark,
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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Object> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = AppwriteService.account.get();
  }

  void _retry() {
    setState(() {
      _sessionFuture = AppwriteService.account.get();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: AppLoadingState(label: 'جاري التحقق من الجلسة'),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is AppwriteException && error.code == 401) {
            return const LoginScreen();
          }

          return Scaffold(
            body: AppErrorState(
              title: 'تعذر الاتصال بالخدمة',
              message:
                  'لم نتمكن من التحقق من الجلسة الحالية. تحقق من الاتصال ثم أعد المحاولة.',
              onRetry: _retry,
            ),
          );
        }

        return const EmployeeShell();
      },
    );
  }
}
