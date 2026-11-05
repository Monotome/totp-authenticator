import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' hide Key;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;

class InvalidPasswordException implements Exception {
  final String message;
  const InvalidPasswordException([this.message = 'Mật khẩu mã hóa không chính xác hoặc dữ liệu bị lỗi.']);

  @override
  String toString() => message;
}

/// Service handling cryptographic key derivation and Fernet encryption/decryption.
/// Matches Python desktop client (`crypto.py`) specifications 100%.
class CryptoService {
  /// Generate a cryptographically secure random 16-byte salt.
  static Uint8List generateSalt([int length = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return Uint8List.fromList(bytes);
  }

  /// Derives a 32-byte raw encryption key using PBKDF2-HMAC-SHA256 (480,000 iterations).
  static Uint8List deriveRawKey(String password, Uint8List salt, {int iterations = 480000}) {
    final derivator = pc.KeyDerivator('SHA-256/HMAC/PBKDF2');
    final params = pc.Pbkdf2Parameters(salt, iterations, 32);
    derivator.init(params);
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Encrypts plaintext using Fernet (AES-128-CBC + HMAC-SHA256).
  /// Returns a URL-safe base64 string identical to Python's Fernet output.
  static String encryptData(String plaintext, String password, Uint8List salt) {
    final rawKey = deriveRawKey(password, salt);
    final fernet = enc.Fernet(enc.Key(rawKey));
    final encrypter = enc.Encrypter(fernet);
    final encrypted = encrypter.encrypt(plaintext);
    return encrypted.base64;
  }

  /// Decrypts a Fernet ciphertext string using the derived key.
  /// Throws [InvalidPasswordException] if password is wrong or ciphertext is corrupted.
  static String decryptData(String ciphertext, String password, Uint8List salt) {
    try {
      final rawKey = deriveRawKey(password, salt);
      final fernet = enc.Fernet(enc.Key(rawKey));
      final encrypter = enc.Encrypter(fernet);
      // Support both standard base64 and urlsafe base64
      final normalized = ciphertext.replaceAll('-', '+').replaceAll('_', '/');
      return encrypter.decrypt64(normalized);
    } catch (e) {
      throw const InvalidPasswordException();
    }
  }

  /// Decrypts in a background isolate using [compute] to keep UI 100% fluid.
  static Future<String> decryptDataAsync(String ciphertext, String password, Uint8List salt) {
    return compute(
      _decryptIsolateEntry,
      _CryptoParams(ciphertext, password, salt),
    );
  }

  /// Encrypts in a background isolate using [compute].
  static Future<String> encryptDataAsync(String plaintext, String password, Uint8List salt) {
    return compute(
      _encryptIsolateEntry,
      _CryptoParams(plaintext, password, salt),
    );
  }
}

class _CryptoParams {
  final String text;
  final String password;
  final Uint8List salt;

  _CryptoParams(this.text, this.password, this.salt);
}

String _decryptIsolateEntry(_CryptoParams params) {
  return CryptoService.decryptData(params.text, params.password, params.salt);
}

String _encryptIsolateEntry(_CryptoParams params) {
  return CryptoService.encryptData(params.text, params.password, params.salt);
}
