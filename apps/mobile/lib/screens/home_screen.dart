import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/sync_provider.dart';
import 'add_account_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountProvider>();
    final syncProvider = context.watch<SyncProvider>();
    final accounts = provider.accounts;
    final remaining = provider.remainingSeconds;
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(l10n.appName),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: l10n.settingsTooltip,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              if (syncProvider.isLoggedIn)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade400,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: accounts.isEmpty ? _buildEmptyState(context, l10n) : _buildList(context, accounts, remaining, theme, l10n),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddAccount(context, l10n),
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          l10n.addAccountButton,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.emptyAccountsTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.emptyAccountsSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Account> accounts, int remaining, ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        // Global countdown bar
        _buildCountdownBar(remaining, theme, l10n),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: accounts.length,
            itemBuilder: (ctx, i) => _buildAccountCard(ctx, accounts[i], remaining, l10n),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownBar(int remaining, ThemeData theme, AppLocalizations l10n) {
    final progress = remaining / 30.0;
    final color = remaining <= 5
        ? theme.colorScheme.error
        : remaining <= 10
            ? Colors.orange
            : theme.colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.refreshingIn, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              Text('${remaining}s', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, Account account, int remaining, AppLocalizations l10n) {
    final provider = context.read<AccountProvider>();
    final code = provider.getCode(account);
    final theme = Theme.of(context);
    final displayName = account.issuer.isNotEmpty ? account.issuer : account.name;

    return Dismissible(
      key: Key(account.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.deleteAccountDialogTitle),
            content: Text(l10n.deleteAccountDialogMessage(displayName)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete, style: TextStyle(color: theme.colorScheme.error)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => provider.removeAccount(account.id),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            provider.copyCode(account);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.copiedToClipboard),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Issuer icon circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (account.issuer.isNotEmpty ? account.issuer : account.name).substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Account info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.issuer.isNotEmpty ? account.issuer : l10n.unknown,
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 2),
                      Text(account.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                // OTP Code
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${code.substring(0, 3)} ${code.substring(3)}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                        color: remaining <= 5 ? theme.colorScheme.error : theme.colorScheme.secondary,
                      ),
                    ),
                    Text(l10n.tapToCopy, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAddAccount(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.addAccountModalTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 20),
            // Option 1: Scan QR
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                );
              },
              icon: const Icon(Icons.qr_code_scanner, size: 22),
              label: Text(
                l10n.scanQrOption,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Enter manually
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddAccountScreen()),
                );
              },
              icon: const Icon(Icons.keyboard_outlined, size: 20),
              label: Text(
                l10n.enterManualOption,
                style: const TextStyle(fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
