import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import 'crypto_service.dart';

/// Coordinates packing, unpacking, and merging accounts with E2EE.
class SyncService {
  /// Packs a list of accounts into an encrypted JSON string matching Desktop format.
  /// Format: `{"s": "<base64Url_salt>", "d": "<fernet_ciphertext>"}`
  static Future<String> packPayload(List<Account> accounts, String syncPassword) async {
    final accountsJson = jsonEncode(accounts.map((a) => a.toJson()).toList());
    final salt = CryptoService.generateSalt(16);

    final encrypted = await CryptoService.encryptDataAsync(accountsJson, syncPassword, salt);
    final saltB64 = base64Url.encode(salt);

    final payloadMap = {
      's': saltB64,
      'd': encrypted,
    };
    return jsonEncode(payloadMap);
  }

  /// Unpacks and decrypts a remote payload string into a list of [Account] objects.
  /// Throws [InvalidPasswordException] or [FormatException] if decryption/parsing fails.
  static Future<List<Account>> unpackPayload(String payloadStr, String syncPassword) async {
    try {
      final payloadMap = jsonDecode(payloadStr) as Map<String, dynamic>;
      final saltStr = payloadMap['s'] as String;
      final encryptedData = payloadMap['d'] as String;

      // Normalize base64Url to standard Uint8List
      final normalizedSalt = base64.normalize(saltStr.replaceAll('-', '+').replaceAll('_', '/'));
      final salt = base64.decode(normalizedSalt);

      final accountsJson = await CryptoService.decryptDataAsync(
        encryptedData,
        syncPassword,
        Uint8List.fromList(salt),
      );

      final list = jsonDecode(accountsJson) as List<dynamic>;
      return list.map((item) => Account.fromJson(item as Map<String, dynamic>)).toList();
    } on InvalidPasswordException {
      rethrow;
    } catch (e) {
      throw FormatException('Không thể giải mã dữ liệu sao lưu: $e');
    }
  }

  /// Merges remote accounts into local accounts without duplicates.
  /// Deduplicates by account ID and by (name + secret) pair.
  static List<Account> mergeAccounts(List<Account> localAccounts, List<Account> remoteAccounts) {
    final merged = List<Account>.from(localAccounts);
    final existingIds = localAccounts.map((a) => a.id).toSet();
    final existingSignatures = localAccounts
        .map((a) => '${a.name.trim().toLowerCase()}|${a.secret.trim().toUpperCase()}')
        .toSet();

    for (final remote in remoteAccounts) {
      if (existingIds.contains(remote.id)) {
        continue;
      }
      final sig = '${remote.name.trim().toLowerCase()}|${remote.secret.trim().toUpperCase()}';
      if (existingSignatures.contains(sig)) {
        continue;
      }

      merged.add(remote);
      existingIds.add(remote.id);
      existingSignatures.add(sig);
    }

    return merged;
  }
}
