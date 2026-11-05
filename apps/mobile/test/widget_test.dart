import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totp_authenticator/main.dart';
import 'package:totp_authenticator/providers/account_provider.dart';
import 'package:totp_authenticator/providers/sync_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AccountProvider()),
          ChangeNotifierProvider(create: (_) => SyncProvider()),
        ],
        child: const TotpApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('🔐 TOTP Authenticator'), findsOneWidget);
  });
}
