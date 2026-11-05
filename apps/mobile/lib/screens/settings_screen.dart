import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncProvider = context.watch<SyncProvider>();
    final securityProvider = context.watch<SecurityProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt & Cloud Sync'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Section 1: Cloud Sync (E2EE)
          _buildSyncCard(context, theme, syncProvider),

          const SizedBox(height: 20),

          // Section 2: App Security & Biometrics
          _buildSecurityCard(context, theme, securityProvider),

          const SizedBox(height: 20),

          // Section 3: App & Security Info
          _buildInfoCard(context, theme),
        ],
      ),
    );
  }

  Widget _buildSyncCard(BuildContext context, ThemeData theme, SyncProvider syncProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: syncProvider.isLoggedIn
            ? _buildConnectedView(context, theme, syncProvider)
            : _buildDisconnectedView(context, theme, syncProvider),
      ),
    );
  }

  Widget _buildConnectedView(BuildContext context, ThemeData theme, SyncProvider syncProvider) {
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
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Đã kết nối',
                    style: TextStyle(
                      color: Colors.green,
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
                'Đăng xuất',
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
              _buildDetailRow('Tài khoản', syncProvider.username, Icons.person_outline, theme),
              const Divider(height: 18),
              _buildDetailRow('Máy chủ', syncProvider.serverUrl, Icons.dns_outlined, theme),
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
            isSyncing ? 'Đang đồng bộ...' : 'Đồng bộ ngay (Sync Now)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                label: const Text('Kéo về (Pull)'),
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
                label: const Text('Đẩy lên (Push)'),
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

  Widget _buildDisconnectedView(BuildContext context, ThemeData theme, SyncProvider syncProvider) {
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
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bảo mật Zero-Knowledge (E2EE)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Máy chủ chỉ lưu trữ blob mã hóa. Khóa mật mã không bao giờ rời khỏi thiết bị.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Server URL Input
          TextFormField(
            controller: _serverUrlController,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ máy chủ (Server URL)',
              prefixIcon: Icon(Icons.dns_outlined, size: 20),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Vui lòng nhập địa chỉ máy chủ';
              return null;
            },
          ),

          const SizedBox(height: 8),

          // Quick Preset Chips for Server URL
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Emulator (10.0.2.2:8000)', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() {
                    _serverUrlController.text = 'http://10.0.2.2:8000';
                  });
                },
              ),
              ActionChip(
                label: const Text('Localhost (127.0.0.1:8000)', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() {
                    _serverUrlController.text = 'http://127.0.0.1:8000';
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Username Input
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Tên người dùng',
              prefixIcon: Icon(Icons.person_outline, size: 20),
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
              labelText: 'Mật khẩu tài khoản',
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
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _isRegisterMode ? 'Đăng ký tài khoản' : 'Đăng nhập',
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
                  ? 'Đã có tài khoản? Đăng nhập ngay'
                  : 'Chưa có tài khoản trên máy chủ? Đăng ký ngay',
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityCard(BuildContext context, ThemeData theme, SecurityProvider security) {
    final isSupported = security.isDeviceSupported;
    final isEnabled = security.isBiometricEnabled;
    final biometricName = security.biometricDisplayName;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                const Text(
                  'Bảo mật ứng dụng',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Biometric Toggle Switch
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Khóa bằng $biometricName',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                !isSupported
                    ? 'Thiết bị không hỗ trợ hoặc chưa đăng ký sinh trắc học'
                    : isEnabled
                        ? 'Yêu cầu xác thực mỗi khi mở ứng dụng'
                        : 'Bảo vệ mã 2FA khỏi người lạ',
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
                            content: const Text('Xác thực thất bại. Không thể thay đổi cài đặt.'),
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
                    'Tự động khóa sau',
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
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Ngay lập tức', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 30, child: Text('30 giây', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 60, child: Text('1 phút', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 300, child: Text('5 phút', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 900, child: Text('15 phút', style: TextStyle(fontSize: 13))),
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
                label: const Text('Khóa ứng dụng ngay (Lock Now)'),
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

  Widget _buildInfoCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                const Text(
                  'Thông tin ứng dụng',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Phiên bản', 'v0.6.3', Icons.tag, theme),
            const Divider(height: 18),
            _buildDetailRow('Tiêu chuẩn 2FA', 'RFC 6238 / RFC 4226', Icons.check_circle_outline, theme),
            const Divider(height: 18),
            _buildDetailRow('Thuật toán E2EE', 'Fernet AES-128-CBC', Icons.security, theme),
            const Divider(height: 18),
            _buildDetailRow('Dẫn xuất khóa', 'PBKDF2 480k rounds', Icons.enhanced_encryption_outlined, theme),
          ],
        ),
      ),
    );
  }
}
