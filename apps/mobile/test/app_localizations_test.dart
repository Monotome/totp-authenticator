import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:totp_authenticator/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations Tests', () {
    test('supports Vietnamese and English locales', () {
      const delegate = AppLocalizationsDelegate();
      expect(delegate.isSupported(const Locale('vi')), isTrue);
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('fr')), isFalse);
    });

    test('fromLocale correctly returns corresponding translation instances', () {
      final vi = AppLocalizations.fromLocale(const Locale('vi'));
      final en = AppLocalizations.fromLocale(const Locale('en'));

      expect(vi.save, 'Lưu');
      expect(en.save, 'Save');

      expect(vi.cancel, 'Hủy');
      expect(en.cancel, 'Cancel');

      expect(vi.settingsTitle, 'Cài đặt & Cloud Sync');
      expect(en.settingsTitle, 'Settings & Cloud Sync');

      expect(vi.appearanceAndLanguageSectionTitle, 'GIAO DIỆN & NGÔN NGỮ');
      expect(en.appearanceAndLanguageSectionTitle, 'APPEARANCE & LANGUAGE');

      expect(vi.themeDark, 'Tối');
      expect(en.themeDark, 'Dark');

      expect(vi.languageVi, 'Tiếng Việt 🇻🇳');
      expect(en.languageEn, 'English 🇬🇧');

      // Validation errors
      expect(vi.usernameErrorEmpty, 'Vui lòng nhập tên người dùng');
      expect(en.usernameErrorEmpty, 'Please enter username');

      expect(vi.passwordErrorEmpty, 'Vui lòng nhập mật khẩu');
      expect(en.passwordErrorEmpty, 'Please enter password');

      expect(vi.serverUrlErrorEmpty, 'Vui lòng nhập địa chỉ máy chủ');
      expect(en.serverUrlErrorEmpty, 'Please enter server URL');

      // Biometrics
      expect(vi.getBiometricName([BiometricType.fingerprint]), 'Vân tay (Fingerprint)');
      expect(en.getBiometricName([BiometricType.fingerprint]), 'Fingerprint');

      expect(vi.getBiometricName([]), 'Mã PIN / Mật khẩu máy');
      expect(en.getBiometricName([]), 'Device Passcode / PIN');

      expect(vi.getBiometricName([BiometricType.face]), 'Khuôn mặt (Face ID)');
      expect(en.getBiometricName([BiometricType.face]), 'Face ID / Facial Recognition');

      // Sync password dialog
      expect(vi.rememberOnDevice, 'Ghi nhớ trên thiết bị này (lưu trong Keystore)');
      expect(en.rememberOnDevice, 'Remember on this device (secure Keystore)');
    });

    test('dynamic parameterized getters work correctly in both languages', () {
      final vi = AppLocalizations.fromLocale(const Locale('vi'));
      final en = AppLocalizations.fromLocale(const Locale('en'));

      expect(vi.deleteAccountDialogMessage('GitHub'), contains('GitHub'));
      expect(en.deleteAccountDialogMessage('GitHub'), contains('GitHub'));

      expect(vi.biometricTitle('Vân tay'), 'Khóa bằng Vân tay');
      expect(en.biometricTitle('Fingerprint'), 'Lock with Fingerprint');

      expect(vi.autoLockSeconds(30), '30 giây');
      expect(en.autoLockSeconds(30), '30 seconds');

      expect(vi.autoLockMinutes(5), '5 phút');
      expect(en.autoLockMinutes(5), '5 minutes');
    });
  });
}
