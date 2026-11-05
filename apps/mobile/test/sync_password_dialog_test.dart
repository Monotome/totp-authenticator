import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totp_authenticator/widgets/sync_password_dialog.dart';

void main() {
  group('SyncPasswordDialog Tests', () {
    testWidgets('renders all dialog elements properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SyncPasswordDialog.show(context),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Mật khẩu mã hóa (E2EE)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Xác nhận'), findsOneWidget);
    });

    testWidgets('submitting empty password shows validation error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SyncPasswordDialog.show(context),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập mật khẩu mã hóa.'), findsOneWidget);
    });

    testWidgets('submitting valid password and checked remember returns result', (tester) async {
      SyncPasswordResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await SyncPasswordDialog.show(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'my-e2ee-secret');
      await tester.tap(find.byType(Checkbox)); // check remember
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.password, equals('my-e2ee-secret'));
      expect(result!.remember, isTrue);
    });
  });
}
