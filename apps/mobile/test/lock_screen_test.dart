import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totp_authenticator/providers/security_provider.dart';
import 'package:totp_authenticator/screens/lock_screen.dart';
import 'package:totp_authenticator/services/biometric_service.dart';

class MockBiometricService extends BiometricService {
  bool mockAuthenticateResult = true;
  int authCallCount = 0;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => [BiometricType.fingerprint];

  @override
  Future<bool> authenticate({
    String localizedReason = 'Xác thực để mở khóa TOTP Authenticator',
    bool biometricOnly = false,
  }) async {
    authCallCount++;
    return mockAuthenticateResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LockScreen Tests', () {
    late MockBiometricService mockService;
    late SecurityProvider securityProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({'security_biometric_enabled': true});
      mockService = MockBiometricService();
      securityProvider = SecurityProvider(
        biometricService: mockService,
        autoInit: false,
      );
    });

    tearDown(() {
      securityProvider.dispose();
    });

    testWidgets('renders all lock screen visual elements', (tester) async {
      await securityProvider.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<SecurityProvider>.value(
          value: securityProvider,
          child: const MaterialApp(
            home: LockScreen(autoPrompt: false, animate: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ứng dụng đã bị khóa'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
      expect(find.textContaining('Mở khóa bằng'), findsOneWidget);
      expect(find.text('Bảo vệ bằng phần cứng an toàn của thiết bị'), findsOneWidget);
    });

    testWidgets('tapping unlock button triggers authenticateAndUnlock', (tester) async {
      await securityProvider.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<SecurityProvider>.value(
          value: securityProvider,
          child: const MaterialApp(
            home: LockScreen(autoPrompt: false, animate: false),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(mockService.authCallCount, equals(1));
      expect(securityProvider.isLocked, isFalse);
    });
  });
}
