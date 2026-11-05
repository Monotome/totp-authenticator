/// Configuration settings for Cloud Sync (E2EE).
class SyncSettings {
  final String serverUrl;
  final String username;
  final String token;
  final double lastSyncedAt;
  final bool rememberPassword;
  final String? savedPassword;

  const SyncSettings({
    this.serverUrl = 'http://10.0.2.2:8000',
    this.username = '',
    this.token = '',
    this.lastSyncedAt = 0.0,
    this.rememberPassword = false,
    this.savedPassword,
  });

  bool get isLoggedIn => token.isNotEmpty;

  SyncSettings copyWith({
    String? serverUrl,
    String? username,
    String? token,
    double? lastSyncedAt,
    bool? rememberPassword,
    String? savedPassword,
    bool clearSavedPassword = false,
  }) {
    return SyncSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      token: token ?? this.token,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rememberPassword: rememberPassword ?? this.rememberPassword,
      savedPassword: clearSavedPassword ? null : (savedPassword ?? this.savedPassword),
    );
  }

  factory SyncSettings.fromJson(Map<String, dynamic> json) {
    return SyncSettings(
      serverUrl: (json['serverUrl'] as String?) ?? 'http://10.0.2.2:8000',
      username: (json['username'] as String?) ?? '',
      token: (json['token'] as String?) ?? '',
      lastSyncedAt: (json['lastSyncedAt'] as num?)?.toDouble() ?? 0.0,
      rememberPassword: (json['rememberPassword'] as bool?) ?? false,
      savedPassword: json['savedPassword'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'username': username,
      'token': token,
      'lastSyncedAt': lastSyncedAt,
      'rememberPassword': rememberPassword,
      'savedPassword': savedPassword,
    };
  }
}
