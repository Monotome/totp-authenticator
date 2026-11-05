import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Base exception for cloud sync API operations.
class SyncApiException implements Exception {
  final String message;
  final int? statusCode;

  const SyncApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Raised when credentials are wrong, token is missing, or session expired (HTTP 401).
class AuthenticationException extends SyncApiException {
  const AuthenticationException([super.message = 'Phiên đăng nhập hết hạn hoặc thông tin không chính xác.'])
      : super(statusCode: 401);
}

/// Raised when server version is newer than the client payload (HTTP 409).
class ConflictException extends SyncApiException {
  const ConflictException([super.message = 'Máy chủ có bản sao lưu mới hơn. Vui lòng Kéo về (Pull) trước.'])
      : super(statusCode: 409);
}

/// HTTP REST client communicating with FastAPI Cloud Sync Backend.
class SyncApiClient {
  final http.Client _client;
  final Duration timeout;

  SyncApiClient({http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _client = client ?? http.Client();

  String _cleanUrl(String serverUrl) {
    var url = serverUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url;
  }

  /// Registers a new user account on the server.
  Future<void> register(String serverUrl, String username, String password) async {
    final base = _cleanUrl(serverUrl);
    final uri = Uri.parse('$base/register');

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      if (response.statusCode == 400) {
        throw const SyncApiException('Tên người dùng đã được đăng ký trên máy chủ.', statusCode: 400);
      }

      _handleErrorResponse(response);
    } on SocketException {
      throw const SyncApiException('Không thể kết nối tới máy chủ. Vui lòng kiểm tra địa chỉ URL và mạng.');
    } on TimeoutException {
      throw const SyncApiException('Hết thời gian chờ phản hồi từ máy chủ.');
    }
  }

  /// Logs in and returns the JWT access token.
  Future<String> login(String serverUrl, String username, String password) async {
    final base = _cleanUrl(serverUrl);
    final uri = Uri.parse('$base/login');

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'username': username, 'password': password},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        if (token == null || token.isEmpty) {
          throw const SyncApiException('Phản hồi từ máy chủ không chứa access_token.');
        }
        return token;
      }

      if (response.statusCode == 401) {
        throw const AuthenticationException('Tên đăng nhập hoặc mật khẩu không chính xác.');
      }

      _handleErrorResponse(response);
      throw const SyncApiException('Đăng nhập thất bại.');
    } on SocketException {
      throw const SyncApiException('Không thể kết nối tới máy chủ. Vui lòng kiểm tra địa chỉ URL và mạng.');
    } on TimeoutException {
      throw const SyncApiException('Hết thời gian chờ phản hồi từ máy chủ.');
    }
  }

  /// Pulls the latest encrypted sync payload from the cloud server.
  /// Returns a Map with 'encrypted_payload' and 'last_updated'.
  Future<Map<String, dynamic>> pullSync(String serverUrl, String token) async {
    final base = _cleanUrl(serverUrl);
    final uri = Uri.parse('$base/sync');

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        throw const AuthenticationException('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }

      _handleErrorResponse(response);
      throw const SyncApiException('Không thể tải dữ liệu từ máy chủ.');
    } on SocketException {
      throw const SyncApiException('Không thể kết nối tới máy chủ.');
    } on TimeoutException {
      throw const SyncApiException('Hết thời gian chờ phản hồi từ máy chủ.');
    }
  }

  /// Pushes encrypted vault payload to the cloud server.
  /// Returns the server response with updated 'last_updated'.
  Future<Map<String, dynamic>> pushSync(
    String serverUrl,
    String token,
    String encryptedPayload,
    double lastUpdated,
  ) async {
    final base = _cleanUrl(serverUrl);
    final uri = Uri.parse('$base/sync');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'encrypted_payload': encryptedPayload,
              'last_updated': lastUpdated,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        throw const AuthenticationException('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }

      if (response.statusCode == 409) {
        throw const ConflictException();
      }

      _handleErrorResponse(response);
      throw const SyncApiException('Không thể đồng bộ dữ liệu lên máy chủ.');
    } on SocketException {
      throw const SyncApiException('Không thể kết nối tới máy chủ.');
    } on TimeoutException {
      throw const SyncApiException('Hết thời gian chờ phản hồi từ máy chủ.');
    }
  }

  void _handleErrorResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('detail')) {
        throw SyncApiException(body['detail'].toString(), statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is SyncApiException) rethrow;
    }
    throw SyncApiException(
      'Lỗi từ máy chủ (HTTP ${response.statusCode}): ${response.reasonPhrase ?? "Không xác định"}',
      statusCode: response.statusCode,
    );
  }

  void dispose() {
    _client.close();
  }
}
