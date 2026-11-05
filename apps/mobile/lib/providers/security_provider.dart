import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_service.dart';

/// State management for app security and biometric lock lifecycle.
class SecurityProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _prefBiometricEnabled = 'security_biometric_enabled';
  static const _prefAutoLockSeconds = 'security_auto_lock_seconds';

  final BiometricService _biometricService;

  bool _isBiometricEnabled = false;
  bool _isLocked = false;
  bool _isDeviceSupported = false;
  List<BiometricType> _availableBiometrics = [];
  int _autoLockSeconds = 0; // 0 = Immediately
  DateTime? _lastPausedAt;
  DateTime? _lastUnlockedAt;
  bool _isAuthenticating = false;
  bool _isInitialized = false;

  SecurityProvider({
    BiometricService? biometricService,
    bool autoInit = true,
  }) : _biometricService = biometricService ?? BiometricService() {
    WidgetsBinding.instance.addObserver(this);
    if (autoInit) {
      init();
    }
  }

  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isLocked => _isLocked;
  bool get isDeviceSupported => _isDeviceSupported;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  int get autoLockSeconds => _autoLockSeconds;
  bool get isAuthenticating => _isAuthenticating;
  bool get isInitialized => _isInitialized;

  String get biometricDisplayName => _biometricService.getBiometricDisplayName(_availableBiometrics);

  /// Initializes preferences, hardware checks, and initial lock state.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isBiometricEnabled = prefs.getBool(_prefBiometricEnabled) ?? false;
      _autoLockSeconds = prefs.getInt(_prefAutoLockSeconds) ?? 0;

      // Lock application immediately on launch if biometrics is enabled
      if (_isBiometricEnabled) {
        _isLocked = true;
      }

      _isDeviceSupported = await _biometricService.isSupported();
      if (_isDeviceSupported) {
        _availableBiometrics = await _biometricService.getAvailableBiometrics();
      }
    } catch (e) {
      debugPrint('Error initializing SecurityProvider: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Toggles biometric protection. Requires user authentication before changing state.
  Future<bool> toggleBiometric(bool enable) async {
    if (enable == _isBiometricEnabled) return true;

    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    notifyListeners();

    try {
      final reason = enable
          ? 'Xác thực để bật bảo vệ sinh trắc học'
          : 'Xác thực để tắt bảo vệ sinh trắc học';

      final authenticated = await _biometricService.authenticate(localizedReason: reason);
      if (!authenticated) {
        return false;
      }

      _isBiometricEnabled = enable;
      if (!enable) {
        _isLocked = false;
      } else {
        // User confirmed biometrics; keep app unlocked in current session
        _isLocked = false;
        _lastPausedAt = null;
        _lastUnlockedAt = DateTime.now();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefBiometricEnabled, enable);
      return true;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  /// Updates the auto-lock delay duration in seconds.
  Future<void> setAutoLockSeconds(int seconds) async {
    _autoLockSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefAutoLockSeconds, seconds);
    notifyListeners();
  }

  /// Triggers biometric authentication and unlocks app on success.
  Future<bool> authenticateAndUnlock() async {
    if (!_isBiometricEnabled || !_isLocked) {
      _isLocked = false;
      _lastPausedAt = null;
      _lastUnlockedAt = DateTime.now();
      notifyListeners();
      return true;
    }

    if (_isAuthenticating) return false;

    _isAuthenticating = true;
    notifyListeners();

    try {
      final success = await _biometricService.authenticate(
        localizedReason: 'Xác thực để mở khóa TOTP Authenticator',
      );

      if (success) {
        _isLocked = false;
        _lastPausedAt = null;
        _lastUnlockedAt = DateTime.now();
      }
      return success;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  /// Manually locks the app if biometric protection is active.
  void lock() {
    if (_isBiometricEnabled && !_isLocked) {
      _isLocked = true;
      notifyListeners();
    }
  }

  /// Direct unlock without biometric check (useful for tests or internal gates).
  void unlockDirectly() {
    _isLocked = false;
    _lastPausedAt = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isBiometricEnabled) return;

    // Ignore lifecycle transitions caused by system BiometricPrompt dialog
    if (_isAuthenticating) {
      _lastPausedAt = null;
      return;
    }

    // Only paused or hidden represent the user leaving the app into the background.
    // Inactive is ignored as it is triggered by system dialogs, notification drawer, or keyboard popups.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Ignore spurious pause events during the immediate dismissal of the auth dialog
      if (_lastUnlockedAt != null &&
          DateTime.now().difference(_lastUnlockedAt!).inMilliseconds < 1000) {
        return;
      }
      _lastPausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastPausedAt != null && !_isLocked) {
        final elapsedSeconds = DateTime.now().difference(_lastPausedAt!).inSeconds;
        if (elapsedSeconds >= _autoLockSeconds) {
          _isLocked = true;
          notifyListeners();
        }
      }
      _lastPausedAt = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
