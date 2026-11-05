import 'package:flutter_test/flutter_test.dart';
import 'package:totp_authenticator/services/qr_parser_service.dart';

void main() {
  group('QrParserService', () {
    test('parses standard otpauth URI with label and query issuer', () {
      const uri =
          'otpauth://totp/Google:alice@gmail.com?secret=JBSWY3DPEHPK3PXP&issuer=Google';
      final account = QrParserService.parseOtpauthUri(uri);

      expect(account.issuer, 'Google');
      expect(account.name, 'alice@gmail.com');
      expect(account.secret, 'JBSWY3DPEHPK3PXP');
    });

    test('parses URI with URL-encoded characters in path label', () {
      const uri =
          'otpauth://totp/GitHub%3Aoctocat%40github.com?secret=JBSWY3DPEHPK3PXP';
      final account = QrParserService.parseOtpauthUri(uri);

      expect(account.issuer, 'GitHub');
      expect(account.name, 'octocat@github.com');
      expect(account.secret, 'JBSWY3DPEHPK3PXP');
    });

    test('handles lowercase secret and removes whitespace and dashes', () {
      const uri =
          'otpauth://totp/MyService:test?secret=jbsw-y3dp-ehpk-3pxp&issuer=MyService';
      final account = QrParserService.parseOtpauthUri(uri);

      expect(account.secret, 'JBSWY3DPEHPK3PXP');
      expect(account.issuer, 'MyService');
      expect(account.name, 'test');
    });

    test('prefers query parameter issuer over path prefix', () {
      const uri =
          'otpauth://totp/OldIssuer:user?secret=JBSWY3DPEHPK3PXP&issuer=NewIssuer';
      final account = QrParserService.parseOtpauthUri(uri);

      expect(account.issuer, 'NewIssuer');
      expect(account.name, 'user');
    });

    test('throws QrParseException on empty or blank input', () {
      expect(
        () => QrParserService.parseOtpauthUri('   '),
        throwsA(isA<QrParseException>()),
      );
    });

    test('throws QrParseException on non-otpauth schemes', () {
      expect(
        () => QrParserService.parseOtpauthUri('https://example.com/2fa'),
        throwsA(isA<QrParseException>()),
      );
    });

    test('throws QrParseException on non-totp type (e.g. hotp)', () {
      expect(
        () => QrParserService.parseOtpauthUri(
            'otpauth://hotp/User?secret=JBSWY3DPEHPK3PXP&counter=1'),
        throwsA(isA<QrParseException>()),
      );
    });

    test('throws QrParseException on missing secret', () {
      expect(
        () => QrParserService.parseOtpauthUri('otpauth://totp/Google:user'),
        throwsA(isA<QrParseException>()),
      );
    });

    test('throws QrParseException on invalid Base32 characters', () {
      // 8 and 9 are invalid in RFC 4648 Base32 alphabet
      expect(
        () => QrParserService.parseOtpauthUri(
            'otpauth://totp/Google:user?secret=INVALID89KEY'),
        throwsA(isA<QrParseException>()),
      );
    });

    test('isValidOtpauthUri returns true for valid and false for invalid', () {
      expect(
        QrParserService.isValidOtpauthUri(
            'otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP'),
        isTrue,
      );
      expect(
        QrParserService.isValidOtpauthUri('not an otpauth url'),
        isFalse,
      );
    });
  });
}
