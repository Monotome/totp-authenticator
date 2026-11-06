import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totp_authenticator/l10n/app_localizations.dart';
import 'package:totp_authenticator/providers/account_provider.dart';
import 'package:totp_authenticator/providers/config_provider.dart';
import 'package:totp_authenticator/providers/security_provider.dart';
import 'package:totp_authenticator/providers/sync_provider.dart';
import 'package:totp_authenticator/screens/home_screen.dart';
import 'package:totp_authenticator/screens/lock_screen.dart';
import 'package:totp_authenticator/screens/settings_screen.dart';
import 'package:totp_authenticator/services/biometric_service.dart';
import 'package:totp_authenticator/services/sync_api_client.dart';
import 'package:totp_authenticator/theme.dart';

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

class MockBiometricService extends BiometricService {
  @override
  Future<bool> isSupported() async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => [
        BiometricType.fingerprint,
      ];

  @override
  Future<bool> authenticate({
    String localizedReason = '',
    bool biometricOnly = false,
  }) async =>
      true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mobile Golden Visual Tests', () {
    late MockBiometricService mockService;
    late SecurityProvider securityProvider;
    late FakeSecureStorage fakeSecureStorage;
    late SyncApiClient mockApiClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'security_biometric_enabled': true,
      });
      mockService = MockBiometricService();
      securityProvider = SecurityProvider(
        biometricService: mockService,
        autoInit: false,
      );
      fakeSecureStorage = FakeSecureStorage();
      mockApiClient = SyncApiClient(client: MockClient((_) async => http.Response('{}', 200)));
    });

    tearDown(() {
      securityProvider.dispose();
      mockApiClient.dispose();
    });

    testWidgets('LockScreen Dark Theme visual layout matches golden image',
        (tester) async {
      await securityProvider.init();

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<SecurityProvider>.value(
          value: securityProvider,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('vi'),
            home: const LockScreen(autoPrompt: false, animate: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(LockScreen),
        matchesGoldenFile('goldens/lock_screen_dark.png'),
      );
    });

    testWidgets('LockScreen Light Theme visual layout matches golden image',
        (tester) async {
      await securityProvider.init();

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<SecurityProvider>.value(
          value: securityProvider,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('vi'),
            home: const LockScreen(autoPrompt: false, animate: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(LockScreen),
        matchesGoldenFile('goldens/lock_screen_light.png'),
      );
    });

    testWidgets('HomeScreen Empty State Dark Theme matches golden image',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final accountProvider = AccountProvider();
      final syncProvider = SyncProvider(
        apiClient: mockApiClient,
        secureStorage: fakeSecureStorage,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
            ChangeNotifierProvider<SecurityProvider>.value(value: securityProvider),
            ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('vi'),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_screen_dark.png'),
      );

      accountProvider.dispose();
      syncProvider.dispose();
    });

    testWidgets('SettingsScreen Disconnected Dark Theme matches golden image',
        (tester) async {
      await securityProvider.init();

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final accountProvider = AccountProvider();
      final syncProvider = SyncProvider(
        apiClient: mockApiClient,
        secureStorage: fakeSecureStorage,
      );
      final configProvider = ConfigProvider();
      await configProvider.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
            ChangeNotifierProvider<SecurityProvider>.value(value: securityProvider),
            ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
            ChangeNotifierProvider<ConfigProvider>.value(value: configProvider),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('vi'),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('goldens/settings_screen_dark.png'),
      );

      accountProvider.dispose();
      syncProvider.dispose();
      configProvider.dispose();
    });
  });
}
