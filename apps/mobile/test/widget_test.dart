import 'package:flutter_test/flutter_test.dart';
import 'package:totp_authenticator/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const TotpApp(),
    );
    expect(find.text('TOTP Authenticator'), findsOneWidget);
  });
}
