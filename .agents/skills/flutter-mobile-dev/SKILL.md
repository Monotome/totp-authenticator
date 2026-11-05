---
name: flutter-mobile-dev
description: Architecture standards, state management, biometric authentication (local_auth), secure storage, QR scanning, and UI patterns for the Flutter TOTP Authenticator mobile app.
---

# Flutter Mobile Development Skill

This skill defines the development guidelines, architecture patterns, and mobile security standards for **`apps/mobile`** in the TOTP Authenticator project.

---

## 1. Project Architecture

The mobile app follows a clean, layered architecture:
```
apps/mobile/lib/
├── models/         # Data classes (Account, SyncPayload, Settings)
├── services/       # Low-level APIs (BiometricService, StorageService, SyncService, OtpService)
├── providers/      # State management using ChangeNotifier & Provider
├── screens/        # Full-page UI views (HomeScreen, ScanScreen, SettingsScreen, UnlockScreen)
├── widgets/        # Reusable UI components (OtpCard, CircularCountdown, ScanOverlay)
└── theme.dart      # Material 3 Dark/Light themes and typography
```

---

## 2. State Management with Provider

* **Separation of Concerns**: Never make network or storage calls directly inside widget build methods. Delegate all business logic to Providers.
* **Selective Rebuilding**: Use `context.select` or `Consumer` to target specific state updates rather than triggering full widget tree rebuilds.

```dart
// Example: Selecting only remaining seconds to avoid rebuilding entire list
final remaining = context.select<TotpProvider, int>((p) => p.remainingSeconds);
```

* **Dispose Controllers**: Ensure `AnimationController`, `TextEditingController`, and `StreamSubscription` instances are canceled in `dispose()`.

---

## 3. Biometric Authentication & Secure Storage

### A. Biometric Auth (`local_auth`)
* Always check `canCheckBiometrics` and `isDeviceSupported()` before attempting biometric unlock.
* Handle platform exceptions (e.g., user canceled, biometric not enrolled, locked out).
* Provide a fallback to Master Password / PIN entry.

```dart
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate() async {
    final bool canAuthenticate = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    if (!canAuthenticate) return false;

    try {
      return await _auth.authenticate(
        localizedReason: 'Xác thực để mở khóa TOTP Authenticator',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}
```

### B. Secure Storage (`flutter_secure_storage`)
* Configure Android options to use `EncryptedSharedPreferences`.
* Configure iOS options to use `kSecAccessControlBiometryAny` or `firstUnlock`.

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

AndroidOptions _getAndroidOptions() => const AndroidOptions(
  encryptedSharedPreferences: true,
);

IOSOptions _getIOSOptions() => const IOSOptions(
  accessibility: KeychainAccessibility.first_unlock,
);
```

---

## 4. QR Code Scanning (`mobile_scanner`)

* Check camera permissions gracefully before launching the scanner view.
* Parse `otpauth://` URIs according to RFC 6238:
  - Format: `otpauth://totp/[Issuer:]Account?secret=BASE32SECRET&issuer=Issuer&digits=6&period=30`
  - Strip spaces, validate Base32 secret before saving.
  - Automatically pause the camera stream once a valid QR code is captured to prevent duplicate scans.

---

## 5. TOTP Generation & Countdown Clock

* Use `otp` package or native HMAC-SHA1/SHA256 calculations:
  ```dart
  import 'package:otp/otp.dart';

  String generateTotp(String secret) {
    return OTP.generateTOTPCodeString(
      secret,
      DateTime.now().millisecondsSinceEpoch,
      interval: 30,
      length: 6,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );
  }
  ```
* Calculate remaining seconds using epoch time to stay synchronized with server time:
  ```dart
  int getRemainingSeconds() {
    return 30 - ((DateTime.now().millisecondsSinceEpoch ~/ 1000) % 30);
  }
  ```
* Run a single 1-second `Timer.periodic` at the app root level (or in `TotpProvider`) and share the tick across all cards.

---

## 6. Testing & Quality Checks

Run from `apps/mobile`:
```bash
flutter test               # Run widget and unit tests
flutter analyze            # Enforce flutter_lints compliance
flutter format --set-exit-if-changed .  # Format check
```
