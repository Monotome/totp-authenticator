import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totp_authenticator/providers/account_provider.dart';
import 'package:totp_authenticator/providers/sync_provider.dart';
import 'package:totp_authenticator/services/sync_api_client.dart';

// In-memory fake secure storage for unit testing
class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = {};

  FakeSecureStorage() : super();

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncProvider Tests', () {
    late FakeSecureStorage fakeSecureStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeSecureStorage = FakeSecureStorage();
    });

    test('initial state is logged out', () {
      final provider = SyncProvider(
        secureStorage: fakeSecureStorage,
      );
      expect(provider.isLoggedIn, isFalse);
      expect(provider.isSyncing, isFalse);
      expect(provider.username, isEmpty);
      expect(provider.lastSyncedAt, equals(0.0));
    });

    test('login sets token and username correctly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'access_token': 'test-token-123', 'token_type': 'bearer'}),
          200,
        );
      });

      final apiClient = SyncApiClient(client: mockClient);
      final provider = SyncProvider(
        apiClient: apiClient,
        secureStorage: fakeSecureStorage,
      );

      await provider.login('http://10.0.2.2:8000', 'alice', 'alice123');

      expect(provider.isLoggedIn, isTrue);
      expect(provider.username, equals('alice'));
      expect(provider.serverUrl, equals('http://10.0.2.2:8000'));
      expect(await fakeSecureStorage.read(key: 'sync_jwt_token'), equals('test-token-123'));
    });

    test('logout clears credentials and token', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'access_token': 'token-to-be-cleared', 'token_type': 'bearer'}),
          200,
        );
      });

      final apiClient = SyncApiClient(client: mockClient);
      final provider = SyncProvider(
        apiClient: apiClient,
        secureStorage: fakeSecureStorage,
      );

      await provider.login('http://10.0.2.2:8000', 'bob', 'pass');
      expect(provider.isLoggedIn, isTrue);

      await provider.logout();
      expect(provider.isLoggedIn, isFalse);
      expect(provider.username, isEmpty);
      expect(await fakeSecureStorage.read(key: 'sync_jwt_token'), isNull);
    });

    test('syncNow coordinates pull, merge, and push', () async {
      int pullCount = 0;
      int pushCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/sync') {
          pullCount++;
          return http.Response(
            jsonEncode({'encrypted_payload': '', 'last_updated': 1700000000.0}),
            200,
          );
        } else if (request.method == 'POST' && request.url.path == '/sync') {
          pushCount++;
          return http.Response(
            jsonEncode({'message': 'OK', 'last_updated': 1700000500.0}),
            200,
          );
        } else if (request.url.path == '/login') {
          return http.Response(
            jsonEncode({'access_token': 'active-token', 'token_type': 'bearer'}),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = SyncApiClient(client: mockClient);
      final provider = SyncProvider(
        apiClient: apiClient,
        secureStorage: fakeSecureStorage,
      );
      final accountProvider = AccountProvider();

      await provider.login('http://10.0.2.2:8000', 'carol', 'secret123');
      await provider.syncNow(accountProvider, 'e2ee-password');

      expect(pullCount, equals(1));
      expect(pushCount, equals(1));
      expect(provider.lastSyncedAt, equals(1700000500.0));
      expect(provider.successMessage, isNotNull);
    });
  });
}
