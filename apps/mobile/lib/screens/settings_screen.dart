import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/account_provider.dart';
import '../providers/config_provider.dart';
import '../providers/security_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/sync_password_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _serverUrlController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final syncProvider = context.read<SyncProvider>();
    _serverUrlController = TextEditingController(text: syncProvider.serverUrl);
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String?> _getOrPromptPassword(SyncProvider syncProvider) async {
    if (syncProvider.savedPassword != null && syncProvider.savedPassword!.isNotEmpty) {
      return syncProvider.savedPassword;
    }

    final result = await SyncPasswordDialog.show(
      context,
      initialRemember: syncProvider.rememberPassword,
    );

    if (result == null) return null;

    if (result.remember) {
      await syncProvider.setRememberPassword(true, result.password);
    }
    return result.password;
  }

  Future<void> _handleSyncNow() async {
    final syncProvider = context.read<SyncProvider>();
    final accountProvider = context.read<AccountProvider>();

    final password = await _getOrPromptPassword(syncProvider);
    if (password == null) return;

    try {
      await syncProvider.syncNow(accountProvider, password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(syncProvider.successMessage ?? 'Đồng bộ hai chiều thành công!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đồng bộ: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handlePull() async {
    final syncProvider = context.read<SyncProvider>();
    final accountProvider = context.read<AccountProvider>();

    final password = await _getOrPromptPassword(syncProvider);
    if (password == null) return;

    try {
      await syncProvider.pull(accountProvider, password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(syncProvider.successMessage ?? 'Kéo dữ liệu thành công!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kéo dữ liệu: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handlePush() async {
    final syncProvider = context.read<SyncProvider>();
    final accountProvider = context.read<AccountProvider>();

    final password = await _getOrPromptPassword(syncProvider);
    if (password == null) return;

    try {
      await syncProvider.push(accountProvider, password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(syncProvider.successMessage ?? 'Đẩy dữ liệu thành công!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đẩy dữ liệu: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleAuthSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final syncProvider = context.read<SyncProvider>();
    final url = _serverUrlController.text.trim();
    final user = _usernameController.text.trim();
    final pass = _passwordController.text;

    try {
      if (_isRegisterMode) {
        await syncProvider.register(url, user, pass);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(syncProvider.successMessage ?? 'Đăng ký thành công! Vui lòng đăng nhập.'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            _isRegisterMode = false;
          });
        }
      } else {
        await syncProvider.login(url, user, pass);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(syncProvider.successMessage ?? 'Đăng nhập thành công!'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatTimestamp(double timestamp) {
    if (timestamp <= 0.0) return 'Chưa đồng bộ';
    final dt = DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).toInt());
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncProvider = context.watch<SyncProvider>();
    final securityProvider = context.watch<SecurityProvider>();
    final configProvider = context.watch<ConfigProvider>();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Section 1: Cloud Sync (E2EE)
          _buildSectionHeader(l10n.cloudSyncSectionTitle),
          _buildSyncCard(context, theme, syncProvider, l10n),

          const SizedBox(height: 24),

          // Section 2: App Security & Biometrics
          _buildSectionHeader(l10n.securitySectionTitle),
          _buildSecurityCard(context, theme, securityProvider, l10n),

          const SizedBox(height: 24),

          // Section 3: Appearance & Language
          _buildSectionHeader(l10n.appearanceAndLanguageSectionTitle),
          _buildPreferencesCard(context, theme, configProvider, l10n),

          const SizedBox(height: 24),

          // Section 4: App & Security Info
          _buildSectionHeader(l10n.systemInfoSectionTitle),
          _buildInfoCard(context, theme, l10n),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSyncCard(BuildContext context, ThemeData theme, SyncProvider syncProvider, AppLocalizations l10n) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: syncProvider.isLoggedIn
            ? _buildConnectedView(context, theme, syncProvider, l10n)
            : _buildDisconnectedView(context, theme, syncProvider, l10n),
      ),
    );
  }

  Widget _buildConnectedView(BuildContext context, ThemeData theme, SyncProvider syncProvider, AppLocalizations l10n) {
    final isSyncing = syncProvider.isSyncing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status Badge Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.statusConnected,
                    style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: isSyncing ? null : () => syncProvider.logout(),
              icon: Icon(Icons.logout, size: 18, color: theme.colorScheme.error),
              label: Text(
                l10n.logoutButton,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Account Details Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              _buildDetailRow(l10n.usernameLabel, syncProvider.username, Icons.person_outline, theme),
              const Divider(height: 18),
              _buildDetailRow(l10n.serverUrlLabel, syncProvider.serverUrl, Icons.dns_outlined, theme),
              const Divider(height: 18),
              _buildDetailRow('Đồng bộ gần nhất', _formatTimestamp(syncProvider.lastSyncedAt), Icons.access_time_outlined, theme),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Primary Action: 1-Click Sync
        FilledButton.icon(
          onPressed: isSyncing ? null : _handleSyncNow,
          icon: isSyncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.sync, size: 20),
          label: Text(
            isSyncing ? 'Đang đồng bộ...' : l10n.syncNowButton,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 12),

        // Secondary Actions: Pull / Push
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSyncing ? null : _handlePull,
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: Text(l10n.pullButton),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSyncing ? null : _handlePush,
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(l10n.pushButton),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // E2EE Keystore Option
        Row(
          children: [
            Icon(
              syncProvider.rememberPassword ? Icons.lock_outline : Icons.lock_open_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ghi nhớ mật khẩu E2EE', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    syncProvider.rememberPassword ? 'Đã lưu an toàn trong Keystore' : 'Hỏi mật khẩu mỗi lần đồng bộ',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            if (syncProvider.rememberPassword)
              TextButton(
                onPressed: () async {
                  await syncProvider.setRememberPassword(false, null);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã xóa mật khẩu E2EE khỏi bộ nhớ bảo mật.')),
                    );
                  }
                },
                child: const Text('Xóa', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDisconnectedView(BuildContext context, ThemeData theme, SyncProvider syncProvider, AppLocalizations l10n) {
    final isSyncing = syncProvider.isSyncing;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Zero-Knowledge Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.zkBannerTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.zkBannerBody,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Server URL Input
          TextFormField(
            controller: _serverUrlController,
            decoration: InputDecoration(
              labelText: l10n.serverUrlLabel,
              prefixIcon: const Icon(Icons.dns_outlined, size: 20),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Vui lòng nhập địa chỉ máy chủ';
              return null;
            },
          ),

          const SizedBox(height: 8),

          // Quick Preset Chips for Server URL
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              children: [
                Text(
                  l10n.serverPresetsLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('Emulator (10.0.2.2:8000)', 'http://10.0.2.2:8000', theme),
                        const SizedBox(width: 8),
                        _buildPresetChip('Localhost (127.0.0.1:8000)', 'http://127.0.0.1:8000', theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Username Input
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: l10n.usernameLabel,
              prefixIcon: const Icon(Icons.person_outline, size: 20),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Vui lòng nhập tên người dùng';
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Password Input
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: l10n.passwordLabel,
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Vui lòng nhập mật khẩu';
              if (_isRegisterMode && val.length < 6) return 'Mật khẩu phải từ 6 ký tự trở lên';
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Submit Action Button
          FilledButton(
            onPressed: isSyncing ? null : _handleAuthSubmit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _isRegisterMode ? l10n.registerButton : l10n.loginButton,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),

          const SizedBox(height: 8),

          // Toggle Mode Button
          TextButton(
            onPressed: isSyncing
                ? null
                : () {
                    setState(() {
                      _isRegisterMode = !_isRegisterMode;
                    });
                  },
            child: Text(
              _isRegisterMode
                  ? l10n.loginSwitchButton
                  : l10n.registerSwitchButton,
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String url, ThemeData theme) {
    return InkWell(
      onTap: () {
        setState(() {
          _serverUrlController.text = url;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              softWrap: true,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(BuildContext context, ThemeData theme, SecurityProvider security, AppLocalizations l10n) {
    final isSupported = security.isDeviceSupported;
    final isEnabled = security.isBiometricEnabled;
    final biometricName = security.biometricDisplayName;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.fingerprint, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.securityCardTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Biometric Toggle Switch
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.biometricTitle(biometricName),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                !isSupported
                    ? l10n.biometricSubtitleUnsupported
                    : isEnabled
                        ? l10n.biometricSubtitleEnabled
                        : l10n.biometricSubtitleDisabled,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              value: isEnabled,
              onChanged: !isSupported
                  ? null
                  : (val) async {
                      final success = await security.toggleBiometric(val);
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.authFailedError),
                            backgroundColor: theme.colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
            ),

            if (isEnabled) ...[
              const Divider(height: 24),

              // Auto-Lock Timeout Dropdown
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 10),
                  Text(
                    l10n.autoLockLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<int>(
                    value: security.autoLockSeconds,
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      DropdownMenuItem(value: 0, child: Text(l10n.autoLockImmediate, style: const TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 30, child: Text(l10n.autoLockSeconds(30), style: const TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 60, child: Text(l10n.autoLockMinutes(1), style: const TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 300, child: Text(l10n.autoLockMinutes(5), style: const TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 900, child: Text(l10n.autoLockMinutes(15), style: const TextStyle(fontSize: 13))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        security.setAutoLockSeconds(val);
                      }
                    },
                  ),
                ],
              ),

              const Divider(height: 24),

              // Lock Now Button
              OutlinedButton.icon(
                onPressed: () {
                  security.lock();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.lock_outline, size: 18),
                label: Text(l10n.lockNowButton),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard(
    BuildContext context,
    ThemeData theme,
    ConfigProvider config,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.palette_outlined, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.appearanceAndLanguageCardTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Item 1: Theme Mode
            Text(
              l10n.themeLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto, size: 16),
                    label: Text(l10n.themeSystem, style: const TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_outlined, size: 16),
                    label: Text(l10n.themeDark, style: const TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode_outlined, size: 16),
                    label: Text(l10n.themeLight, style: const TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {config.themeMode},
                onSelectionChanged: (newSelection) {
                  config.setThemeMode(newSelection.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),

            const Divider(height: 28),

            // Item 2: Display Language
            Row(
              children: [
                Icon(
                  Icons.language_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.languageLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: config.languageCode,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(l10n.languageSystem, style: const TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: 'vi',
                      child: Text(l10n.languageVi, style: const TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(l10n.languageEn, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      config.setLanguageCode(val);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.appInfoTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildDetailRow(l10n.versionLabel, 'v0.8.2', Icons.tag, theme),
            const Divider(height: 18),
            _buildDetailRow(l10n.twoFaStandardLabel, 'RFC 6238 / RFC 4226', Icons.check_circle_outline, theme),
            const Divider(height: 18),
            _buildDetailRow(l10n.e2eeAlgorithmLabel, 'Fernet AES-128-CBC', Icons.security, theme),
            const Divider(height: 18),
            _buildDetailRow(l10n.keyDerivationLabel, 'PBKDF2 480k rounds', Icons.enhanced_encryption_outlined, theme),
          ],
        ),
      ),
    );
  }
}
