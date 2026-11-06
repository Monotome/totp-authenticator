import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../services/qr_parser_service.dart';
import 'scan_screen.dart';

class AddAccountScreen extends StatefulWidget {
  final Account? initialAccount;

  const AddAccountScreen({
    super.key,
    this.initialAccount,
  });

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _secretController = TextEditingController();
  final _issuerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialAccount != null) {
      _nameController.text = widget.initialAccount!.name;
      _secretController.text = widget.initialAccount!.secret;
      _issuerController.text = widget.initialAccount!.issuer;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _secretController.dispose();
    _issuerController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final account = Account(
      id: widget.initialAccount?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      secret: _secretController.text.trim().replaceAll(' ', '').toUpperCase(),
      issuer: _issuerController.text.trim(),
    );

    context.read<AccountProvider>().addAccount(account);
    Navigator.pop(context, true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.accountSavedMessage(account.name)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Parse an otpauth:// URI pasted by the user
  void _pasteUri() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final uri = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.enterUriDialogTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.enterUriDialogHint,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l10n.importText),
          ),
        ],
      ),
    );
    if (uri == null || uri.trim().isEmpty) return;
    _parseOtpauthUri(uri);
  }

  void _parseOtpauthUri(String raw) {
    try {
      final parsed = QrParserService.parseOtpauthUri(raw);
      setState(() {
        _nameController.text = parsed.name;
        _secretController.text = parsed.secret;
        _issuerController.text = parsed.issuer;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.extractSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on QrParseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${e.message}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.error}: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openQrScanner() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.initialAccount != null;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.editAccountTitle : l10n.addAccountTitle),
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: l10n.scanQrOption,
              onPressed: _openQrScanner,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isEditing) ...[
                // Scan QR Code shortcut button
                FilledButton.tonalIcon(
                  onPressed: _openQrScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(
                    l10n.scanQrOption,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Import URI button
                OutlinedButton.icon(
                  onPressed: _pasteUri,
                  icon: const Icon(Icons.link),
                  label: Text(l10n.pasteUriButton),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'hoặc / or',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Issuer
              TextFormField(
                controller: _issuerController,
                decoration: InputDecoration(
                  labelText: l10n.issuerLabel,
                  hintText: l10n.issuerHint,
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Account name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '${l10n.accountNameLabel} *',
                  hintText: l10n.accountNameHint,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.accountNameError : null,
              ),
              const SizedBox(height: 16),

              // Secret key
              TextFormField(
                controller: _secretController,
                decoration: InputDecoration(
                  labelText: '${l10n.secretKeyLabel} *',
                  hintText: l10n.secretKeyHint,
                  prefixIcon: const Icon(Icons.key_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.secretKeyErrorEmpty;
                  }
                  final clean = v.trim().replaceAll(' ', '').toUpperCase();
                  if (!RegExp(r'^[A-Z2-7]+=*$').hasMatch(clean)) {
                    return l10n.secretKeyErrorInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: Text(
                  isEditing ? l10n.save : l10n.addAccountButton,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
