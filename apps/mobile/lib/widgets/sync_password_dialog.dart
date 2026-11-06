import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Result returned from [SyncPasswordDialog].
class SyncPasswordResult {
  final String password;
  final bool remember;

  const SyncPasswordResult({
    required this.password,
    required this.remember,
  });
}

/// Dialog prompting user to enter E2EE master sync password.
class SyncPasswordDialog extends StatefulWidget {
  final bool initialRemember;

  const SyncPasswordDialog({
    super.key,
    this.initialRemember = false,
  });

  /// Static helper to display the dialog and retrieve results.
  static Future<SyncPasswordResult?> show(
    BuildContext context, {
    bool initialRemember = false,
  }) {
    return showDialog<SyncPasswordResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SyncPasswordDialog(initialRemember: initialRemember),
    );
  }

  @override
  State<SyncPasswordDialog> createState() => _SyncPasswordDialogState();
}

class _SyncPasswordDialogState extends State<SyncPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscureText = true;
  late bool _remember;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _remember = widget.initialRemember;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _controller.text;
    if (password.isEmpty) {
      setState(() {
        _errorText = context.l10n.vaultPasswordErrorEmpty;
      });
      return;
    }

    Navigator.of(context).pop(
      SyncPasswordResult(
        password: password,
        remember: _remember,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.lock_outline, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.vaultPasswordTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.vaultPasswordDescription,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              obscureText: _obscureText,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.vaultPasswordLabel,
                errorText: _errorText,
                prefixIcon: const Icon(Icons.key_outlined, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                setState(() {
                  _remember = !_remember;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _remember,
                      onChanged: (val) {
                        setState(() {
                          _remember = val ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        l10n.rememberOnDevice,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
