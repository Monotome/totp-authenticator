import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _secretController = TextEditingController();
  final _issuerController = TextEditingController();

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
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      secret: _secretController.text.trim().replaceAll(' ', ''),
      issuer: _issuerController.text.trim(),
    );

    context.read<AccountProvider>().addAccount(account);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Account added successfully!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Parse an otpauth:// URI
  void _pasteUri() async {
    final controller = TextEditingController();
    final uri = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste otpauth:// URI'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'otpauth://totp/...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Import')),
        ],
      ),
    );
    if (uri == null || uri.isEmpty) return;
    _parseOtpauthUri(uri);
  }

  void _parseOtpauthUri(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != 'otpauth' || uri.host != 'totp') {
        throw const FormatException('Not an otpauth://totp URI');
      }
      // Path is /Issuer:account or /account
      var label = uri.pathSegments.isNotEmpty ? Uri.decodeComponent(uri.pathSegments.last) : '';
      final secret = uri.queryParameters['secret'] ?? '';
      var issuer = uri.queryParameters['issuer'] ?? '';

      if (label.contains(':')) {
        final parts = label.split(':');
        if (issuer.isEmpty) issuer = parts[0].trim();
        label = parts.length > 1 ? parts[1].trim() : parts[0].trim();
      }

      setState(() {
        _nameController.text = label;
        _secretController.text = secret;
        _issuerController.text = issuer;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid URI: $e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Add Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Import URI button
              OutlinedButton.icon(
                onPressed: _pasteUri,
                icon: const Icon(Icons.link),
                label: const Text('Import from otpauth:// URI'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or enter manually', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                ),
                Expanded(child: Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.2))),
              ]),
              const SizedBox(height: 24),
              // Issuer
              TextFormField(
                controller: _issuerController,
                decoration: const InputDecoration(
                  labelText: 'Issuer (e.g. Google, GitHub)',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),
              // Account name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account Name *',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Account name is required' : null,
              ),
              const SizedBox(height: 16),
              // Secret key
              TextFormField(
                controller: _secretController,
                decoration: const InputDecoration(
                  labelText: 'Secret Key *',
                  prefixIcon: Icon(Icons.key),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Secret key is required' : null,
              ),
              const SizedBox(height: 32),
              // Submit
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text('Add Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
