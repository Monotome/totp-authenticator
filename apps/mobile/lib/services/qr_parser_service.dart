import '../models/account.dart';

/// Exception thrown when parsing an invalid or unsupported 2FA QR code.
class QrParseException implements Exception {
  final String message;
  const QrParseException(this.message);

  @override
  String toString() => message;
}

/// Service dedicated to parsing and validating RFC 6238 otpauth:// URIs.
class QrParserService {
  static final RegExp _base32Regex = RegExp(r'^[A-Z2-7]+=*$');

  /// Parses an otpauth:// TOTP URI string into an [Account] model.
  /// Throws [QrParseException] if the URI format or secret is invalid.
  static Account parseOtpauthUri(String rawUri) {
    final trimmed = rawUri.trim();
    if (trimmed.isEmpty) {
      throw const QrParseException('Mã QR trống.');
    }

    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.toLowerCase() != 'otpauth') {
      throw const QrParseException('Không phải mã QR xác thực 2FA hợp lệ (thiếu otpauth://).');
    }

    final type = uri.host.toLowerCase();
    if (type != 'totp') {
      throw QrParseException('Giao thức "$type" hiện chưa được hỗ trợ (chỉ hỗ trợ TOTP).');
    }

    // 1. Parse Label from path (/Issuer:AccountName or /AccountName)
    String label = '';
    if (uri.pathSegments.isNotEmpty) {
      label = Uri.decodeComponent(uri.pathSegments.join('/'));
      // Remove leading slash if any
      if (label.startsWith('/')) {
        label = label.substring(1);
      }
    }

    String queryIssuer = uri.queryParameters['issuer']?.trim() ?? '';
    String extractedIssuer = '';
    String accountName = label.trim();

    if (accountName.contains(':')) {
      final parts = accountName.split(':');
      extractedIssuer = parts[0].trim();
      accountName = parts.sublist(1).join(':').trim();
    }

    // Determine final issuer: prefer query param if present, fallback to label prefix
    final finalIssuer = queryIssuer.isNotEmpty
        ? queryIssuer
        : extractedIssuer;

    if (accountName.isEmpty) {
      accountName = finalIssuer.isNotEmpty ? finalIssuer : 'Tài khoản không tên';
    }

    // 2. Extract and validate secret
    final rawSecret = uri.queryParameters['secret'];
    if (rawSecret == null || rawSecret.trim().isEmpty) {
      throw const QrParseException('Mã QR thiếu tham số bí mật (secret).');
    }

    final cleanSecret = rawSecret.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    if (!_base32Regex.hasMatch(cleanSecret)) {
      throw const QrParseException('Mã bí mật (Secret key) không đúng định dạng Base32.');
    }

    if (cleanSecret.replaceAll('=', '').length < 8) {
      throw const QrParseException('Độ dài mã bí mật quá ngắn (tối thiểu 8 ký tự).');
    }

    return Account(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: accountName,
      secret: cleanSecret,
      issuer: finalIssuer,
    );
  }

  /// Quick check whether a string looks like a supported otpauth:// TOTP URI.
  static bool isValidOtpauthUri(String rawUri) {
    try {
      parseOtpauthUri(rawUri);
      return true;
    } catch (_) {
      return false;
    }
  }
}
