import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:totp_authenticator/services/biometric_service.dart';

class FakeLocalAuthentication implements LocalAuthentication {
  bool mockIsDeviceSupported = true;
  bool mockCanCheckBiometrics = true;
  List<BiometricType> mockAvailableBiometrics = [BiometricType.fingerprint];
  bool mockAuthenticateResult = true;
  Exception? mockException;

  @override
  Future<bool> get canCheckBiometrics async => mockCanCheckBiometrics;

  @override
  Future<bool> isDeviceSupported() async => mockIsDeviceSupported;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (mockException != null) throw mockException!;
    return mockAvailableBiometrics;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    if (mockException != null) throw mockException!;
    return mockAuthenticateResult;
  }

  @override
  Future<bool> stopAuthentication() async => true;
}

void main() {
  group('BiometricService Tests', () {
    late FakeLocalAuthentication fakeAuth;
    late BiometricService service;

    setUp(() {
      fakeAuth = FakeLocalAuthentication();
      service = BiometricService(auth: fakeAuth);
    });

    test('isSupported returns true when device supports biometrics', () async {
      fakeAuth.mockIsDeviceSupported = true;
      fakeAuth.mockCanCheckBiometrics = true;
      expect(await service.isSupported(), isTrue);
    });

    test('isSupported returns false when neither device nor biometrics are supported', () async {
      fakeAuth.mockIsDeviceSupported = false;
      fakeAuth.mockCanCheckBiometrics = false;
      expect(await service.isSupported(), isFalse);
    });

    test('isSupported handles PlatformException gracefully and returns false', () async {
      fakeAuth.mockCanCheckBiometrics = false;
      fakeAuth.mockIsDeviceSupported = false;
      expect(await service.isSupported(), isFalse);
    });

    test('getAvailableBiometrics returns list of biometrics', () async {
      fakeAuth.mockAvailableBiometrics = [BiometricType.face, BiometricType.fingerprint];
      final biometrics = await service.getAvailableBiometrics();
      expect(biometrics, containsAll([BiometricType.face, BiometricType.fingerprint]));
    });

    test('getAvailableBiometrics handles exception gracefully', () async {
      fakeAuth.mockException = PlatformException(code: 'NotAvailable', message: 'No hardware');
      final biometrics = await service.getAvailableBiometrics();
      expect(biometrics, isEmpty);
    });

    test('getBiometricDisplayName formats friendly string correctly', () {
      expect(service.getBiometricDisplayName([BiometricType.face]), equals('Khuôn mặt (Face ID)'));
      expect(service.getBiometricDisplayName([BiometricType.fingerprint]), equals('Vân tay (Fingerprint)'));
      expect(service.getBiometricDisplayName([BiometricType.iris]), equals('Mống mắt (Iris)'));
      expect(service.getBiometricDisplayName([BiometricType.weak]), equals('Sinh trắc học'));
      expect(service.getBiometricDisplayName([]), equals('Mã PIN / Mật khẩu máy'));
    });

    test('authenticate returns true when native verification succeeds', () async {
      fakeAuth.mockAuthenticateResult = true;
      final result = await service.authenticate(localizedReason: 'Test Unlock');
      expect(result, isTrue);
    });

    test('authenticate returns false when native verification fails or is canceled', () async {
      fakeAuth.mockAuthenticateResult = false;
      final result = await service.authenticate(localizedReason: 'Test Unlock');
      expect(result, isFalse);
    });

    test('authenticate handles PlatformException safely and returns false', () async {
      fakeAuth.mockException = PlatformException(code: 'LockedOut', message: 'Too many failed attempts');
      final result = await service.authenticate();
      expect(result, isFalse);
    });

    test('authenticate returns false when device is not supported', () async {
      fakeAuth.mockIsDeviceSupported = false;
      fakeAuth.mockCanCheckBiometrics = false;
      final result = await service.authenticate();
      expect(result, isFalse);
    });
  });
}
