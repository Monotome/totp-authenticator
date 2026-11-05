import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totp_authenticator/providers/account_provider.dart';
import 'package:totp_authenticator/providers/sync_provider.dart';
import 'package:totp_authenticator/screens/settings_screen.dart';
import 'package:totp_authenticator/services/sync_api_client.dart';

class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> storage = {};

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
      storage[key] = value;
    } else {
      storage.remove(key);
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
    return storage[key];
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
    storage.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen Tests', () {
    late FakeSecureStorage fakeSecureStorage;
    late AccountProvider accountProvider;
    late SyncApiClient mockApiClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeSecureStorage = FakeSecureStorage();
      accountProvider = AccountProvider();
      mockApiClient = SyncApiClient(client: MockClient((_) async => http.Response('{}', 200)));
    });

    tearDown(() {
      accountProvider.dispose();
      mockApiClient.dispose();
    });

    testWidgets('renders disconnected view with zero-knowledge banner and form fields', (tester) async {
      final syncProvider = SyncProvider(
        apiClient: mockApiClient,
        secureStorage: fakeSecureStorage,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
            ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bảo mật Zero-Knowledge (E2EE)'), findsOneWidget);
      expect(find.text('Địa chỉ máy chủ (Server URL)'), findsOneWidget);
      expect(find.text('Tên người dùng'), findsOneWidget);
      expect(find.text('Mật khẩu tài khoản'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Chưa có tài khoản trên máy chủ? Đăng ký ngay'), findsOneWidget);

      // Verify preset chips exist
      expect(find.text('Emulator (10.0.2.2:8000)'), findsOneWidget);
      expect(find.text('Localhost (127.0.0.1:8000)'), findsOneWidget);

      // Scroll down to reveal Info Card
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Thông tin ứng dụng'), findsOneWidget);
      expect(find.text('v0.6.3'), findsOneWidget);

      syncProvider.dispose();
    });

    testWidgets('tapping preset chip updates Server URL text field', (tester) async {
      final syncProvider = SyncProvider(
        apiClient: mockApiClient,
        secureStorage: fakeSecureStorage,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
            ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Localhost (127.0.0.1:8000)'));
      await tester.pumpAndSettle();

      expect(find.text('http://127.0.0.1:8000'), findsOneWidget);

      syncProvider.dispose();
    });

    testWidgets('toggling register mode changes button label and prompt', (tester) async {
      final syncProvider = SyncProvider(
        apiClient: mockApiClient,
        secureStorage: fakeSecureStorage,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
            ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chưa có tài khoản trên máy chủ? Đăng ký ngay'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng ký tài khoản'), findsOneWidget);
      expect(find.text('Đã có tài khoản? Đăng nhập ngay'), findsOneWidget);

      syncProvider.dispose();
    });

    testWidgets('renders connected view with sync buttons when logged in', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'access_token': 'test-token', 'token_type': 'bearer'}),
          200,
        );
      });

      final apiClient = SyncApiClient(client: mockClient);
      final syncProvider = SyncProvider(
        apiClient: apiClient,
        secureStorage: fakeSecureStorage,
      );

      await syncProvider.login('http://10.0.2.2:8000', 'super_user', 'pass');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
            ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đã kết nối'), findsOneWidget);
      expect(find.text('super_user'), findsOneWidget);
      expect(find.text('Đồng bộ ngay (Sync Now)'), findsOneWidget);
      expect(find.text('Kéo về (Pull)'), findsOneWidget);
      expect(find.text('Đẩy lên (Push)'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);

      syncProvider.dispose();
    });
  });
}
