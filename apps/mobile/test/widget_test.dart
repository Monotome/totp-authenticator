import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:totp_authenticator/main.dart';
import 'package:totp_authenticator/providers/account_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AccountProvider(),
        child: const TotpApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('🔐 TOTP Authenticator'), findsOneWidget);
  });
}
