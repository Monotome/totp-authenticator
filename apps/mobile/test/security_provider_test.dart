import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totp_authenticator/providers/security_provider.dart';
import 'package:totp_authenticator/services/biometric_service.dart';

class MockBiometricService extends BiometricService {
  bool mockIsSupported = true;
  List<BiometricType> mockBiometrics = [BiometricType.fingerprint];
  bool mockAuthenticateResult = true;
  int authenticateCallCount = 0;

  @override
  Future<bool> isSupported() async => mockIsSupported;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => mockBiometrics;

  @override
  Future<bool> authenticate({
    String localizedReason = 'Xác thực để mở khóa TOTP Authenticator',
    bool biometricOnly = false,
  }) async {
    authenticateCallCount++;
    return mockAuthenticateResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityProvider Tests', () {
    late MockBiometricService mockService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockService = MockBiometricService();
    });

    test('initial state defaults to disabled and unlocked', () async {
      final provider = SecurityProvider(
        biometricService: mockService,
        autoInit: false,
      );
      await provider.init();

      expect(provider.isBiometricEnabled, isFalse);
      expect(provider.isLocked, isFalse);
      expect(provider.autoLockSeconds, equals(0));
      expect(provider.isDeviceSupported, isTrue);
      expect(provider.availableBiometrics, contains(BiometricType.fingerprint));

      provider.dispose();
    });

    test('initial state locks on startup if biometrics was previously enabled', () async {
      SharedPreferences.setMockInitialValues({
        'security_biometric_enabled': true,
        'security_auto_lock_seconds': 30,
      });

      final provider = SecurityProvider(
        biometricService: mockService,
        autoInit: false,
      );
      await provider.init();

      expect(provider.isBiometricEnabled, isTrue);
      expect(provider.isLocked, isTrue);
      expect(provider.autoLockSeconds, equals(30));

      provider.dispose();
    });

    test('toggleBiometric enables protection on successful authentication', () async {
      final provider = SecurityProvider(
        biometricService: mockService,
        autoInit: false,
      );
      await provider.init();

      mockService.mockAuthenticateResult = true;
      final success = await provider.toggleBiometric(true);

      expect(success, isTrue);
      expect(provider.isBiometricEnabled, isTrue);
      expect(mockService.authenticateCallCount, equals(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('security_biometric_enabled'), isTrue);

      provider.dispose();
    });

    test('toggleBiometric does not enable if authentication fails or is cancelled', () async {
      final provider = SecurityProvider(
        biometricService: mockService,
        autoInit: false,
      );
      await provider.init();

      mockService.mockAuthenticateResult = false;
      final success = await provider.toggleBiometric(true);

      expect(success, isFalse);
      expect(provider.isBiometricEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('security_biometric_enabled'), isNull);

      provider.dispose();
    });

    test('authenticateAndUnlock unlocks app when authentication succeeds', () async {
      SharedPreferences.setMockInitialValues({'security_biometric_enabled': true});

      final provider = SecurityProvider(
        biometricService: mockService,
        autoInit: false,
      );
      await provider.init();
      expect(provider.isLocked, isTrue);

      mockService.mockAuthenticateResult = true;
      final unlocked = await provider.authenticateAndUnlock();

      expect(unlocked, isTrue);
      expect(provider.isLocked, isFalse);

      provider.dispose();
    });

    test('authenticateAndUnlock keeps locked when authentication fails', () async {
      SharedPreferences.setMockInitialValues({'security_biometric_enabled': true});

      final provider = SecurityProvider(
        biometricService: mockService,
        autoInit: false,
      );
      await provider.init();
      expect(provider.isLocked, isTrue);

      mockService.mockAuthenticateResult = false;
      final unlocked = await provider.authenticateAndUnlock();

      expect(unlocked, isFalse);
      expect(provider.isLocked, isTrue);

      provider.dispose();
    });

    test('manual lock() sets isLocked to true when biometrics is enabled', () async {
      SharedPreferences.setMockInitialValues({'security_biometric_enabled': true});

      final provider = SecurityProvider(
        biometricService: mockService,
        autoInit: false,
      );
      await provider.init();

      provider.unlockDirectly();
      expect(provider.isLocked, isFalse);

      provider.lock();
      expect(provider.isLocked, isTrue);

      provider.dispose();
    });

    test('lifecycle triggers lock when paused duration exceeds autoLockSeconds', () async {
      SharedPreferences.setMockInitialValues({
        'security_biometric_enabled': true,
        'security_auto_lock_seconds': 0, // Immediately
      });

      final provider = SecurityProvider(
        biometricService: mockService,
        autoInit: false,
      );
      await provider.init();
      provider.unlockDirectly();
      expect(provider.isLocked, isFalse);

      // App is paused
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(provider.isLocked, isFalse);

      // App is resumed
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(provider.isLocked, isTrue);

      provider.dispose();
    });
  });
}
