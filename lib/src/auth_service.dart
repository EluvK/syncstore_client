import 'package:dio/dio.dart';
import 'token_storage.dart';
import 'exceptions.dart';

/// AuthService: handles login / refresh / register.
/// It knows the auth endpoints and persists tokens into TokenStorage.
///
/// Assumes server paths (as discussed): POST /api/auth/name-login, POST /api/auth/refresh
class AuthService {
  final Dio dio;
  final TokenStorage _storage;

  AuthService(this.dio, this._storage);

  /// Login with username & password. On success store tokens.
  /// Returns map with raw response if needed.
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final resp = await dio.post('/auth/name-login', data: {
        'username': username,
        'password': password,
      });
      final data = _normalizeResp(resp);
      _persistTokens(data);
      return data;
    } on DioError catch (e) {
      throw _wrapDioError(e);
    }
  }

  /// Refresh tokens using refresh token. Returns true if refreshed.
  Future<bool> refresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) {
      return false;
    }
    try {
      final resp = await dio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      final data = _normalizeResp(resp);
      _persistTokens(data);
      return true;
    } on DioError catch (e) {
      // treat any error as refresh failure
      return false;
    }
  }

  /// Optional register helper for admin usage
  Future<void> register(String username, String password) async {
    try {
      await dio.post('/admin/register', data: {'username': username, 'password': password});
    } on DioError catch (e) {
      throw _wrapDioError(e);
    }
  }

  void _persistTokens(Map<String, dynamic> data) {
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    // server may send expiry seconds or expiry timestamp
    DateTime? accessExpiry;
    if (data.containsKey('expires_in')) {
      final expires = data['expires_in'];
      if (expires is int) accessExpiry = DateTime.now().add(Duration(seconds: expires));
    }
    if (access != null) {
      _storage.setAccessToken(access, expiry: accessExpiry);
    }
    if (refresh != null) {
      _storage.setRefreshToken(refresh);
    }
  }

  Map<String, dynamic> _normalizeResp(Response resp) {
    if (resp.data is Map<String, dynamic>) return resp.data as Map<String, dynamic>;
    return {'raw': resp.data};
  }

  Exception _wrapDioError(DioError e) {
    if (e.response != null && e.response?.statusCode == 401) {
      return AuthException('Unauthorized');
    }
    return ApiException('Auth request failed: ${e.message}');
  }
}
