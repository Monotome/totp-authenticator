import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/account.dart';
import '../services/storage_service.dart';
import '../services/totp_service.dart';

/// Central state manager for TOTP accounts.
/// Feeds data to all screens via Provider.
class AccountProvider extends ChangeNotifier {
  List<Account> _accounts = [];
  int _remainingSeconds = 30;
  Timer? _timer;

  List<Account> get accounts => _accounts;
  int get remainingSeconds => _remainingSeconds;

  AccountProvider() {
    _load();
    _startTimer();
  }

  Future<void> _load() async {
    _accounts = await StorageService.loadAccounts();
    notifyListeners();
  }

  void _startTimer() {
    _remainingSeconds = TotpService.getRemainingSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds = TotpService.getRemainingSeconds();
      notifyListeners();
    });
  }

  /// Generate the current OTP code for the given account.
  String getCode(Account account) {
    return TotpService.getCode(account.secret);
  }

  /// Add a new account and persist.
  Future<void> addAccount(Account account) async {
    _accounts.add(account);
    await StorageService.saveAccounts(_accounts);
    notifyListeners();
  }

  /// Replace all accounts (used during Cloud Sync merge) and persist.
  Future<void> replaceAccounts(List<Account> newAccounts) async {
    _accounts = List<Account>.from(newAccounts);
    await StorageService.saveAccounts(_accounts);
    notifyListeners();
  }

  /// Remove an account by id and persist.
  Future<void> removeAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    await StorageService.saveAccounts(_accounts);
    notifyListeners();
  }

  /// Copy an OTP code to the system clipboard.
  void copyCode(Account account) {
    Clipboard.setData(ClipboardData(text: getCode(account)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
