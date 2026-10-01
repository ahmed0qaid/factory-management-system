import 'package:flutter_test/flutter_test.dart';
import 'package:hr_employee_system/services/app_biometric_lock_service.dart';

void main() {
  group('AppBiometricLockService preference key', () {
    test('scopes secure device lock preference to the current user', () {
      expect(
        AppBiometricLockService.preferenceKeyForUser('user-123'),
        'biometrics_enabled_user-123',
      );
    });

    test('different users never share the same local lock setting', () {
      expect(
        AppBiometricLockService.preferenceKeyForUser('user-123'),
        isNot(AppBiometricLockService.preferenceKeyForUser('user-456')),
      );
    });

    test('trims accidental whitespace from user id', () {
      expect(
        AppBiometricLockService.preferenceKeyForUser('  user-123  '),
        'biometrics_enabled_user-123',
      );
    });
  });
}
