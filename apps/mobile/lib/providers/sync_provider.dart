import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_settings.dart';
import '../services/sync_api_client.dart';
import '../services/sync_service.dart';
import 'account_provider.dart';

/// State management for Cloud Synchronization (E2EE).
class SyncProvider extends ChangeNotifier {
  static const _prefServerUrl = 'sync_server_url';
  static const _prefUsername = 'sync_username';
  static const _prefLastSyncedAt = 'sync_last_synced_at';
  static const _prefRememberPassword = 'sync_remember_password';

  static const _secToken = 'sync_jwt_token';
  static const _secPassword = 'sync_e2ee_password';

  final SyncApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;

  SyncSettings _settings = const SyncSettings();
  bool _isSyncing = false;
  String? _errorMessage;
  String? _successMessage;

  SyncProvider({
    SyncApiClient? apiClient,
    FlutterSecureStorage? secureStorage,
  })  : _apiClient = apiClient ?? SyncApiClient(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _loadSettings();
  }

  SyncSettings get settings => _settings;
  bool get isLoggedIn => _settings.isLoggedIn;
  bool get isSyncing => _isSyncing;
  String get serverUrl => _settings.serverUrl;
  String get username => _settings.username;
  double get lastSyncedAt => _settings.lastSyncedAt;
  bool get rememberPassword => _settings.rememberPassword;
  String? get savedPassword => _settings.savedPassword;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_prefServerUrl) ?? 'http://10.0.2.2:8000';
      final user = prefs.getString(_prefUsername) ?? '';
      final lastSynced = prefs.getDouble(_prefLastSyncedAt) ?? 0.0;
      final remember = prefs.getBool(_prefRememberPassword) ?? false;

      final token = await _secureStorage.read(key: _secToken) ?? '';
      String? savedPass;
      if (remember) {
        savedPass = await _secureStorage.read(key: _secPassword);
      }

      _settings = SyncSettings(
        serverUrl: url,
        username: user,
        token: token,
        lastSyncedAt: lastSynced,
        rememberPassword: remember,
        savedPassword: savedPass,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading sync settings: $e');
    }
  }

  /// Sets or updates the target sync server URL.
  Future<void> setServerUrl(String url) async {
    _settings = _settings.copyWith(serverUrl: url.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerUrl, _settings.serverUrl);
    notifyListeners();
  }

  /// Register a new account on the sync server.
  Future<void> register(String serverUrl, String username, String password) async {
    _isSyncing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _apiClient.register(serverUrl, username, password);
      _successMessage = 'Đăng ký tài khoản thành công! Vui lòng đăng nhập.';
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Login to the sync server and store the JWT in secure hardware storage.
  Future<void> login(String serverUrl, String username, String password) async {
    _isSyncing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final token = await _apiClient.login(serverUrl, username, password);

      await _secureStorage.write(key: _secToken, value: token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefServerUrl, serverUrl.trim());
      await prefs.setString(_prefUsername, username.trim());

      _settings = _settings.copyWith(
        serverUrl: serverUrl.trim(),
        username: username.trim(),
        token: token,
      );
      _successMessage = 'Đăng nhập thành công!';
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Log out and wipe stored tokens and saved passwords.
  Future<void> logout() async {
    _isSyncing = true;
    notifyListeners();

    try {
      await _secureStorage.delete(key: _secToken);
      await _secureStorage.delete(key: _secPassword);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefUsername);
      await prefs.remove(_prefLastSyncedAt);
      await prefs.remove(_prefRememberPassword);

      _settings = _settings.copyWith(
        token: '',
        username: '',
        lastSyncedAt: 0.0,
        rememberPassword: false,
        clearSavedPassword: true,
      );
      _successMessage = 'Đã đăng xuất.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Save or remove the remembered E2EE master password in Keystore.
  Future<void> setRememberPassword(bool remember, String? password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefRememberPassword, remember);

    if (remember && password != null && password.isNotEmpty) {
      await _secureStorage.write(key: _secPassword, value: password);
      _settings = _settings.copyWith(rememberPassword: true, savedPassword: password);
    } else {
      await _secureStorage.delete(key: _secPassword);
      _settings = _settings.copyWith(rememberPassword: false, clearSavedPassword: true);
    }
    notifyListeners();
  }

  /// Pull latest vault from server, decrypt, and merge into local accounts.
  Future<void> pull(AccountProvider accountProvider, String e2eePassword) async {
    if (!isLoggedIn) {
      throw const AuthenticationException('Chưa đăng nhập máy chủ đồng bộ.');
    }

    _isSyncing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final data = await _apiClient.pullSync(_settings.serverUrl, _settings.token);
      final payload = data['encrypted_payload'] as String?;
      final serverTimestamp = (data['last_updated'] as num?)?.toDouble() ?? 0.0;

      if (payload != null && payload.isNotEmpty) {
        final cloudAccounts = await SyncService.unpackPayload(payload, e2eePassword);
        final merged = SyncService.mergeAccounts(accountProvider.accounts, cloudAccounts);
        await accountProvider.replaceAccounts(merged);
      }

      await _updateLastSynced(serverTimestamp > 0.0 ? serverTimestamp : _now());
      _successMessage = 'Kéo dữ liệu từ Cloud thành công!';
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Encrypt local accounts and push to server.
  Future<void> push(AccountProvider accountProvider, String e2eePassword) async {
    if (!isLoggedIn) {
      throw const AuthenticationException('Chưa đăng nhập máy chủ đồng bộ.');
    }

    _isSyncing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final payload = await SyncService.packPayload(accountProvider.accounts, e2eePassword);
      final timestamp = _now();
      final resp = await _apiClient.pushSync(_settings.serverUrl, _settings.token, payload, timestamp);
      final newTimestamp = (resp['last_updated'] as num?)?.toDouble() ?? timestamp;

      await _updateLastSynced(newTimestamp);
      _successMessage = 'Đẩy dữ liệu lên Cloud thành công!';
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// One-click full bidirectional sync: Pull -> Merge -> Push.
  Future<void> syncNow(AccountProvider accountProvider, String e2eePassword) async {
    if (!isLoggedIn) {
      throw const AuthenticationException('Chưa đăng nhập máy chủ đồng bộ.');
    }

    _isSyncing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // 1. Pull from server
      final data = await _apiClient.pullSync(_settings.serverUrl, _settings.token);
      final payload = data['encrypted_payload'] as String?;

      if (payload != null && payload.isNotEmpty) {
        final cloudAccounts = await SyncService.unpackPayload(payload, e2eePassword);
        final merged = SyncService.mergeAccounts(accountProvider.accounts, cloudAccounts);
        await accountProvider.replaceAccounts(merged);
      }

      // 2. Encrypt merged accounts and push back
      final updatedPayload = await SyncService.packPayload(accountProvider.accounts, e2eePassword);
      final timestamp = _now();

      Map<String, dynamic> resp;
      try {
        resp = await _apiClient.pushSync(_settings.serverUrl, _settings.token, updatedPayload, timestamp);
      } on ConflictException {
        // If conflict occurs during push, retry once with fresh pull
        final retryData = await _apiClient.pullSync(_settings.serverUrl, _settings.token);
        final retryPayload = retryData['encrypted_payload'] as String?;
        if (retryPayload != null && retryPayload.isNotEmpty) {
          final retryCloud = await SyncService.unpackPayload(retryPayload, e2eePassword);
          final remerged = SyncService.mergeAccounts(accountProvider.accounts, retryCloud);
          await accountProvider.replaceAccounts(remerged);
        }
        final finalPayload = await SyncService.packPayload(accountProvider.accounts, e2eePassword);
        resp = await _apiClient.pushSync(_settings.serverUrl, _settings.token, finalPayload, _now());
      }

      final newTimestamp = (resp['last_updated'] as num?)?.toDouble() ?? timestamp;
      await _updateLastSynced(newTimestamp);
      _successMessage = 'Đồng bộ hai chiều thành công!';
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _updateLastSynced(double timestamp) async {
    _settings = _settings.copyWith(lastSyncedAt: timestamp);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefLastSyncedAt, timestamp);
  }

  double _now() => DateTime.now().millisecondsSinceEpoch / 1000.0;

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }
}
