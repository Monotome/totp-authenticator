import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Low-level service wrapping [LocalAuthentication] for biometric authentication.
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  /// Checks if the device hardware supports biometrics or device passcode/PIN.
  Future<bool> isSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported || canCheck;
    } on PlatformException catch (e) {
      debugPrint('Error checking biometric support: $e');
      return false;
    } catch (e) {
      debugPrint('Unexpected error checking biometric support: $e');
      return false;
    }
  }

  /// Retrieves the list of enrolled/available biometric sensors on this device.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    } catch (e) {
      debugPrint('Unexpected error getting available biometrics: $e');
      return [];
    }
  }

  /// Friendly display name for the available biometric type.
  String getBiometricDisplayName(List<BiometricType> types, {String? languageCode}) {
    if (languageCode == 'en') {
      if (types.contains(BiometricType.face)) return 'Face ID / Facial Recognition';
      if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
      if (types.contains(BiometricType.iris)) return 'Iris Recognition';
      if (types.isNotEmpty) return 'Biometrics';
      return 'Device Passcode / PIN';
    }
    if (types.contains(BiometricType.face)) {
      return 'Khuôn mặt (Face ID)';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Vân tay (Fingerprint)';
    } else if (types.contains(BiometricType.iris)) {
      return 'Mống mắt (Iris)';
    } else if (types.isNotEmpty) {
      return 'Sinh trắc học';
    }
    return 'Mã PIN / Mật khẩu máy';
  }

  /// Prompts the native OS biometric verification sheet.
  /// Falls back to device PIN/Pattern if [biometricOnly] is false.
  Future<bool> authenticate({
    String localizedReason = 'Xác thực để mở khóa TOTP Authenticator',
    bool biometricOnly = false,
  }) async {
    try {
      final supported = await isSupported();
      if (!supported) {
        debugPrint('Biometrics not supported on this device.');
        return false;
      }

      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication PlatformException: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Biometric authentication unexpected error: $e');
      return false;
    }
  }

  /// Stops ongoing authentication if supported by platform.
  Future<bool> cancelAuthentication() async {
    try {
      return await _auth.stopAuthentication();
    } catch (_) {
      return false;
    }
  }
}
