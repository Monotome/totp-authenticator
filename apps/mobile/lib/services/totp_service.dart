import 'package:otp/otp.dart';

/// Service responsible for generating TOTP codes.
class TotpService {
  /// Generate a 6-digit TOTP code from a base32-encoded [secret].
  static String getCode(String secret) {
    try {
      return OTP.generateTOTPCodeString(
        secret.replaceAll(' ', '').toUpperCase(),
        DateTime.now().millisecondsSinceEpoch,
        algorithm: Algorithm.SHA1,
        length: 6,
        interval: 30,
        isGoogle: true,
      );
    } catch (_) {
      return '------';
    }
  }

  /// Seconds remaining in the current 30-second TOTP window.
  static int getRemainingSeconds() {
    return 30 - ((DateTime.now().millisecondsSinceEpoch ~/ 1000) % 30);
  }
}
