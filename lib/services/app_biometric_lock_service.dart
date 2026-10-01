import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppBiometricAuthResult {
  final bool authenticated;
  final String? message;

  const AppBiometricAuthResult({
    required this.authenticated,
    this.message,
  });
}

class AppBiometricLockService {
  final LocalAuthentication _localAuth;

  AppBiometricLockService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  static String preferenceKeyForUser(String userId) =>
      'biometrics_enabled_${userId.trim()}';

  Future<bool> isAvailable() async {
    try {
      return await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabledForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(preferenceKeyForUser(userId)) ?? false;
  }

  Future<void> setEnabledForUser(String userId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preferenceKeyForUser(userId), enabled);
  }

  Future<AppBiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    final available = await isAvailable();
    if (!available) {
      return const AppBiometricAuthResult(
        authenticated: false,
        message:
            'تعذر استخدام البصمة على هذا الجهاز. يمكنك إعادة المحاولة أو تسجيل الخروج.',
      );
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (!authenticated) {
        return const AppBiometricAuthResult(
          authenticated: false,
          message: 'لم يتم التحقق من البصمة.',
        );
      }

      return const AppBiometricAuthResult(authenticated: true);
    } on LocalAuthException catch (error) {
      final message = switch (error.code) {
        LocalAuthExceptionCode.userCanceled => 'تم إلغاء التحقق من البصمة.',
        LocalAuthExceptionCode.temporaryLockout =>
          'تم إيقاف البصمة مؤقتًا بسبب محاولات متكررة. حاول لاحقًا.',
        LocalAuthExceptionCode.biometricLockout =>
          'البصمة مقفلة على الجهاز. افتح الجهاز بالطريقة الأساسية ثم أعد المحاولة.',
        _ => 'تعذر التحقق من البصمة. لم يتم تجاوز حماية التطبيق.',
      };
      return AppBiometricAuthResult(authenticated: false, message: message);
    } catch (_) {
      return const AppBiometricAuthResult(
        authenticated: false,
        message: 'حدث خطأ أثناء التحقق من البصمة. لم يتم تجاوز حماية التطبيق.',
      );
    }
  }
}
