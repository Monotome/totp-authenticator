import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totp_authenticator/main.dart';
import 'package:totp_authenticator/providers/account_provider.dart';
import 'package:totp_authenticator/providers/config_provider.dart';
import 'package:totp_authenticator/providers/security_provider.dart';
import 'package:totp_authenticator/providers/sync_provider.dart';
import 'package:totp_authenticator/services/biometric_service.dart';

class MockBiometricService extends BiometricService {
  @override
  Future<bool> isSupported() async => false;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ConfigProvider(autoInit: false)..init()),
          ChangeNotifierProvider(create: (_) => SecurityProvider(biometricService: MockBiometricService(), autoInit: false)..init()),
          ChangeNotifierProvider(create: (_) => AccountProvider()),
          ChangeNotifierProvider(create: (_) => SyncProvider()),
        ],
        child: const TotpApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('TOTP Authenticator'), findsOneWidget);
  });
}
