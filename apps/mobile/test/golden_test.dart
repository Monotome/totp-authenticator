import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totp_authenticator/providers/security_provider.dart';
import 'package:totp_authenticator/screens/lock_screen.dart';
import 'package:totp_authenticator/services/biometric_service.dart';
import 'package:totp_authenticator/theme.dart';

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

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'security_biometric_enabled': true,
      });
      mockService = MockBiometricService();
      securityProvider = SecurityProvider(
        biometricService: mockService,
        autoInit: false,
      );
    });

    tearDown(() {
      securityProvider.dispose();
    });

    testWidgets('LockScreen Dark Theme visual layout matches golden image',
        (tester) async {
      await securityProvider.init();

      // Set standard phone viewport (e.g. Pixel 4 / iPhone 13 aspect ratio)
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
  });
}
