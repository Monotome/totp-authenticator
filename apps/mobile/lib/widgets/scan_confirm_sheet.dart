import 'dart:async';
import 'package:flutter/material.dart';
import '../models/account.dart';
import '../services/totp_service.dart';
import '../theme.dart';

enum ScanConfirmAction {
  save,
  edit,
}

/// Confirmation Bottom Sheet displayed after a successful QR scan.
/// Displays parsed metadata along with a live OTP preview so the user
/// can verify the code before saving.
class ScanConfirmSheet extends StatefulWidget {
  final Account account;

  const ScanConfirmSheet({
    super.key,
    required this.account,
  });

  /// Static helper to display the sheet modally.
  static Future<ScanConfirmAction?> show(BuildContext context, Account account) {
    return showModalBottomSheet<ScanConfirmAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ScanConfirmSheet(account: account),
    );
  }

  @override
  State<ScanConfirmSheet> createState() => _ScanConfirmSheetState();
}

class _ScanConfirmSheetState extends State<ScanConfirmSheet> {
  late String _currentCode;
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateOtp();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateOtp();
      }
    });
  }

  void _updateOtp() {
    setState(() {
      _currentCode = TotpService.getCode(widget.account.secret);
      _remainingSeconds = TotpService.getRemainingSeconds();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = widget.account;
    final displayIssuer =
        account.issuer.isNotEmpty ? account.issuer : 'Không xác định';
    final initialLetter =
        (account.issuer.isNotEmpty ? account.issuer : account.name)
            .substring(0, 1)
            .toUpperCase();

    final countdownColor = _remainingSeconds <= 5
        ? AppTheme.accentRed
        : _remainingSeconds <= 10
            ? Colors.orange
            : AppTheme.accentGreen;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.accentGreen, size: 24),
              const SizedBox(width: 8),
              Text(
                'Mã QR hợp lệ!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Account Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                // Issuer Avatar circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      initialLetter,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Issuer & Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayIssuer,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live OTP Preview Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accentCyan.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MÃ XÁC THỰC HIỆN TẠI',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentCode.length == 6
                          ? '${_currentCode.substring(0, 3)} ${_currentCode.substring(3)}'
                          : _currentCode,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                  ],
                ),
                // Remaining seconds circular badge
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: countdownColor),
                    const SizedBox(width: 4),
                    Text(
                      '${_remainingSeconds}s',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: countdownColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, ScanConfirmAction.save),
            icon: const Icon(Icons.check, size: 20),
            label: const Text(
              'Thêm tài khoản',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: AppTheme.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, ScanConfirmAction.edit),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Chỉnh sửa thông tin'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
