import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:totp_authenticator/models/account.dart';
import 'package:totp_authenticator/services/crypto_service.dart';
import 'package:totp_authenticator/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService Tests', () {
    final sampleAccounts = [
      Account(id: 'acc-1', name: 'GitHub: user1', secret: 'JBSWY3DPEHPK3PXP', issuer: 'GitHub'),
      Account(id: 'acc-2', name: 'Google: user1@gmail.com', secret: 'HXDMVJECJJWSRB3H', issuer: 'Google'),
    ];
    const password = 'StrongSyncPassword!456';

    test('packPayload and unpackPayload roundtrip restores accounts accurately', () async {
      final payload = await SyncService.packPayload(sampleAccounts, password);

      // Verify payload structure {"s": "...", "d": "..."}
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      expect(decoded.containsKey('s'), isTrue);
      expect(decoded.containsKey('d'), isTrue);

      final restored = await SyncService.unpackPayload(payload, password);
      expect(restored.length, equals(2));
      expect(restored[0].id, equals('acc-1'));
      expect(restored[0].name, equals('GitHub: user1'));
      expect(restored[0].secret, equals('JBSWY3DPEHPK3PXP'));
      expect(restored[0].issuer, equals('GitHub'));

      expect(restored[1].id, equals('acc-2'));
      expect(restored[1].name, equals('Google: user1@gmail.com'));
      expect(restored[1].secret, equals('HXDMVJECJJWSRB3H'));
      expect(restored[1].issuer, equals('Google'));
    });

    test('unpackPayload throws InvalidPasswordException on wrong password', () async {
      final payload = await SyncService.packPayload(sampleAccounts, password);

      expect(
        () async => await SyncService.unpackPayload(payload, 'WrongPassword!'),
        throwsA(isA<InvalidPasswordException>()),
      );
    });

    test('unpackPayload throws FormatException on invalid payload format', () async {
      expect(
        () async => await SyncService.unpackPayload('invalid-json', password),
        throwsA(isA<FormatException>()),
      );
    });

    test('mergeAccounts deduplicates accounts by ID and (name, secret)', () {
      final local = [
        Account(id: 'id-1', name: 'Work GitHub', secret: 'SECRET1', issuer: 'GitHub'),
        Account(id: 'id-2', name: 'Personal Google', secret: 'SECRET2', issuer: 'Google'),
      ];

      final remote = [
        // Duplicate ID
        Account(id: 'id-1', name: 'Work GitHub Updated', secret: 'SECRET1', issuer: 'GitHub'),
        // Duplicate (name, secret) with different ID
        Account(id: 'id-diff', name: 'personal google', secret: 'secret2', issuer: 'Google'),
        // Brand new account
        Account(id: 'id-3', name: 'AWS Cloud', secret: 'SECRET3', issuer: 'AWS'),
      ];

      final merged = SyncService.mergeAccounts(local, remote);

      expect(merged.length, equals(3));
      expect(merged.map((a) => a.id).toList(), containsAll(['id-1', 'id-2', 'id-3']));
      expect(merged[0].name, equals('Work GitHub')); // Kept original
      expect(merged[2].id, equals('id-3'));
      expect(merged[2].name, equals('AWS Cloud'));
    });

    test('Cross-platform verification: unpack payload format compatible with Python Desktop', () async {
      // Simulate Desktop Python sync_manager._pack_payload format:
      // {"s": "<base64_url_salt>", "d": "<fernet_ciphertext>"}
      const syncPass = 'test_desktop_pass';
      final salt = CryptoService.generateSalt(16);

      final accountsJson = jsonEncode([
        {'id': 'desktop-1', 'name': 'Desktop User', 'secret': 'JBSWY3DPEHPK3PXP', 'issuer': 'PythonApp'}
      ]);

      // Fernet encrypt
      final cipherText = CryptoService.encryptData(accountsJson, syncPass, salt);
      final payloadMap = {
        's': base64Url.encode(salt),
        'd': cipherText,
      };
      final payloadJson = jsonEncode(payloadMap);

      final unpacked = await SyncService.unpackPayload(payloadJson, syncPass);
      expect(unpacked.length, equals(1));
      expect(unpacked[0].id, equals('desktop-1'));
      expect(unpacked[0].name, equals('Desktop User'));
      expect(unpacked[0].secret, equals('JBSWY3DPEHPK3PXP'));
      expect(unpacked[0].issuer, equals('PythonApp'));
    });
  });
}
