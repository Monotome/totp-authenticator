import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:totp_authenticator/services/sync_api_client.dart';

void main() {
  group('SyncApiClient Tests', () {
    const serverUrl = 'http://localhost:8000';

    test('register succeeds when server returns 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/register'));
        expect(request.method, equals('POST'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['username'], equals('testuser'));
        expect(body['password'], equals('password123'));
        return http.Response(jsonEncode({'message': 'User registered'}), 200);
      });

      final client = SyncApiClient(client: mockClient);
      await expectLater(client.register(serverUrl, 'testuser', 'password123'), completes);
    });

    test('register throws SyncApiException when username already exists (400)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Username already registered.'}), 400);
      });

      final client = SyncApiClient(client: mockClient);
      expect(
        () async => await client.register(serverUrl, 'existinguser', 'password123'),
        throwsA(isA<SyncApiException>()),
      );
    });

    test('login returns access_token on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/login'));
        expect(request.method, equals('POST'));
        expect(request.headers['content-type'], contains('application/x-www-form-urlencoded'));
        return http.Response(
          jsonEncode({
            'access_token': 'fake-jwt-token-xyz',
            'token_type': 'bearer',
          }),
          200,
        );
      });

      final client = SyncApiClient(client: mockClient);
      final token = await client.login(serverUrl, 'user', 'pass');
      expect(token, equals('fake-jwt-token-xyz'));
    });

    test('login throws AuthenticationException on 401', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Incorrect username or password'}), 401);
      });

      final client = SyncApiClient(client: mockClient);
      expect(
        () async => await client.login(serverUrl, 'user', 'wrongpass'),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('pullSync returns server sync data on 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/sync'));
        expect(request.method, equals('GET'));
        expect(request.headers['Authorization'], equals('Bearer valid-token'));
        return http.Response(
          jsonEncode({
            'encrypted_payload': '{"s":"salt","d":"cipher"}',
            'last_updated': 1700000000.0,
          }),
          200,
        );
      });

      final client = SyncApiClient(client: mockClient);
      final data = await client.pullSync(serverUrl, 'valid-token');
      expect(data['encrypted_payload'], equals('{"s":"salt","d":"cipher"}'));
      expect(data['last_updated'], equals(1700000000.0));
    });

    test('pullSync throws AuthenticationException on 401', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
      });

      final client = SyncApiClient(client: mockClient);
      expect(
        () async => await client.pullSync(serverUrl, 'expired-token'),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('pushSync returns response on 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/sync'));
        expect(request.method, equals('POST'));
        expect(request.headers['Authorization'], equals('Bearer valid-token'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['encrypted_payload'], equals('payload-data'));
        expect(body['last_updated'], equals(1700000100.0));
        return http.Response(
          jsonEncode({
            'message': 'Sync successful',
            'last_updated': 1700000100.0,
          }),
          200,
        );
      });

      final client = SyncApiClient(client: mockClient);
      final resp = await client.pushSync(serverUrl, 'valid-token', 'payload-data', 1700000100.0);
      expect(resp['message'], equals('Sync successful'));
      expect(resp['last_updated'], equals(1700000100.0));
    });

    test('pushSync throws ConflictException on 409', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Conflict: Server has a newer version.'}),
          409,
        );
      });

      final client = SyncApiClient(client: mockClient);
      expect(
        () async => await client.pushSync(serverUrl, 'valid-token', 'payload-data', 1600000000.0),
        throwsA(isA<ConflictException>()),
      );
    });
  });
}
