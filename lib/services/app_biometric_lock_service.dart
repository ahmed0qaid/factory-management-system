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
      // isDeviceSupported covers biometric authentication and the platform's
      // secure device credential fallback (PIN/password/pattern) when allowed.
      return await _localAuth.isDeviceSupported();
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
            'تعذر استخدام حماية الجهاز. يمكنك إعادة المحاولة أو تسجيل الخروج.',
      );
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (!authenticated) {
        return const AppBiometricAuthResult(
          authenticated: false,
          message: 'لم يتم التحقق من هوية المستخدم.',
        );
      }

      return const AppBiometricAuthResult(authenticated: true);
    } on LocalAuthException catch (error) {
      final message = switch (error.code) {
        LocalAuthExceptionCode.userCanceled => 'تم إلغاء التحقق من الهوية.',
        LocalAuthExceptionCode.temporaryLockout =>
          'تم إيقاف التحقق مؤقتًا بسبب محاولات متكررة. حاول لاحقًا أو استخدم قفل الجهاز عند ظهوره.',
        LocalAuthExceptionCode.biometricLockout =>
          'البصمة مقفلة. استخدم رمز أو كلمة مرور الجهاز عند ظهور خيار قفل الجهاز.',
        _ => 'تعذر التحقق من الهوية. لم يتم تجاوز حماية التطبيق.',
      };
      return AppBiometricAuthResult(authenticated: false, message: message);
    } catch (_) {
      return const AppBiometricAuthResult(
        authenticated: false,
        message: 'حدث خطأ أثناء التحقق من الهوية. لم يتم تجاوز حماية التطبيق.',
      );
    }
  }
}
