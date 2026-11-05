import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totp_authenticator/providers/account_provider.dart';
import 'package:totp_authenticator/providers/security_provider.dart';
import 'package:totp_authenticator/providers/sync_provider.dart';
import 'package:totp_authenticator/screens/home_screen.dart';
import 'package:totp_authenticator/screens/lock_screen.dart';
import 'package:totp_authenticator/services/biometric_service.dart';
import 'package:totp_authenticator/widgets/auth_gate.dart';

class MockBiometricService extends BiometricService {
  bool mockAuthenticateResult = true;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => [BiometricType.fingerprint];

  @override
  Future<bool> authenticate({
    String localizedReason = 'Xác thực để mở khóa TOTP Authenticator',
    bool biometricOnly = false,
  }) async => mockAuthenticateResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthGate Tests', () {
    late SecurityProvider securityProvider;
    late AccountProvider accountProvider;
    late SyncProvider syncProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      accountProvider = AccountProvider();
      syncProvider = SyncProvider();
    });

    tearDown(() {
      accountProvider.dispose();
      syncProvider.dispose();
      securityProvider.dispose();
    });

    testWidgets('shows HomeScreen when biometrics is disabled', (tester) async {
      securityProvider = SecurityProvider(
        biometricService: MockBiometricService(),
        autoInit: false,
      );
      await securityProvider.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SecurityProvider>.value(value: securityProvider),
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
            ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
          ],
          child: const MaterialApp(
            home: AuthGate(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('🔐 TOTP Authenticator'), findsOneWidget);
      expect(find.byType(LockScreen), findsNothing);
    });

    testWidgets('shows LockScreen when biometrics is enabled and locked', (tester) async {
      SharedPreferences.setMockInitialValues({'security_biometric_enabled': true});
      final mockBiometric = MockBiometricService()..mockAuthenticateResult = false;

      securityProvider = SecurityProvider(
        biometricService: mockBiometric,
        autoInit: false,
      );
      await securityProvider.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SecurityProvider>.value(value: securityProvider),
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
            ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
          ],
          child: const MaterialApp(
            home: AuthGate(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.text('Ứng dụng đã bị khóa'), findsOneWidget);
    });

    testWidgets('transitions to HomeScreen after unlock without infinite loop', (tester) async {
      SharedPreferences.setMockInitialValues({'security_biometric_enabled': true});
      final mockBiometric = MockBiometricService()..mockAuthenticateResult = false;

      securityProvider = SecurityProvider(
        biometricService: mockBiometric,
        autoInit: false,
      );
      await securityProvider.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SecurityProvider>.value(value: securityProvider),
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
            ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
          ],
          child: const MaterialApp(
            home: AuthGate(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LockScreen), findsOneWidget);

      // Now user unlocks with biometric
      mockBiometric.mockAuthenticateResult = true;
      final unlocked = await securityProvider.authenticateAndUnlock();
      expect(unlocked, isTrue);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LockScreen), findsNothing);
    });
  });
}
