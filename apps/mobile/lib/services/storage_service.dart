import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';

/// Handles local JSON persistence via SharedPreferences.
class StorageService {
  static const _key = 'totp_accounts';

  /// Load all saved accounts from local storage.
  static Future<List<Account>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Persist entire account list to local storage.
  static Future<void> saveAccounts(List<Account> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_key, json);
  }
}
