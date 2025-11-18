import 'package:dio/dio.dart';
import 'package:result_dart/result_dart.dart';
import 'auth_interceptor.dart';
import 'token_storage.dart';
import 'models.dart';
import 'errors.dart';

/// SyncStoreClient: minimal, generic CRUD client.
///
/// - baseUrl should point to server API root, e.g. http://localhost:7878/api
/// - tokenStorage: store for tokens
class SyncStoreClient {
  final Dio _dio;
  final TokenStorage tokenStorage;
  final AuthService authService;

  SyncStoreClient._(this._dio, this.tokenStorage, this.authService);

  factory SyncStoreClient({
    required String baseUrl,
    required TokenStorage tokenStorage,
    Dio? dio,
  }) {
    final client = dio ?? Dio(BaseOptions(baseUrl: baseUrl));
    final authSrv = AuthService(client, tokenStorage);
    client.interceptors.add(AuthInterceptor(tokenStorage, authSrv));
    return SyncStoreClient._(client, tokenStorage, authSrv);
  }

  // Authentication helpers
  Future<void> login(String username, String password) async {
    await authService.login(username, password);
  }

  Future<void> logout() async {
    await tokenStorage.clear();
  }

  /// Generic create: returns the raw response mapped to T using fromMap.
  Future<T> create<T>(
      String namespace, String collection, Map<String, dynamic> body, T Function(Map<String, dynamic>) fromMap) async {
    try {
      final resp = await _dio.post('/data/$namespace/$collection', data: body);
      final data = resp.data as Map<String, dynamic>;
      return fromMap(data);
    } on DioException catch (e) {
      throw _wrapDioException(e);
    }
  }

  Future<T> get<T>(String namespace, String collection, String id, T Function(Map<String, dynamic>) fromMap) async {
    try {
      final resp = await _dio.get('/data/$namespace/$collection/$id');
      final data = resp.data as Map<String, dynamic>;
      return fromMap(data);
    } on DioException catch (e) {
      throw _wrapDioException(e);
    }
  }

  Future<T> update<T>(String namespace, String collection, String id, Map<String, dynamic> body,
      T Function(Map<String, dynamic>) fromMap) async {
    try {
      final resp = await _dio.post('/data/$namespace/$collection/$id', data: body);
      final data = resp.data as Map<String, dynamic>;
      return fromMap(data);
    } on DioException catch (e) {
      throw _wrapDioException(e);
    }
  }

  Future<void> delete(String namespace, String collection, String id) async {
    try {
      await _dio.delete('/data/$namespace/$collection/$id');
    } on DioException catch (e) {
      throw _wrapDioException(e);
    }
  }

  /// list with optional parentId, marker, limit
  Future<ListResponse<T>> list<T>(
    String namespace,
    String collection, {
    String? parentId,
    String? marker,
    int limit = 50,
    required T Function(Map<String, dynamic>) fromMap,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (parentId != null) query['parent_id'] = parentId;
      if (marker != null) query['marker'] = marker;
      query['limit'] = limit;
      final resp = await _dio.get('/data/$namespace/$collection', queryParameters: query);
      final data = resp.data as Map<String, dynamic>;
      return ListResponse.fromMap(data, fromMap);
    } on DioException catch (e) {
      throw _wrapDioException(e);
    }
  }
}

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
  ApiResult<bool> login(String username, String password) async {
    try {
      final resp = await dio.post(
        '/auth/name-login',
        data: {'username': username, 'password': password},
        options: Options(extra: {'skipAuthInterceptor': true}),
      );
      final data = _normalizeResp(resp);
      _persistTokens(data);
      return Success(true);
    } on DioException catch (e) {
      return Failure(_wrapDioException(e));
    }
  }

  /// Refresh tokens using refresh token. Returns true if refreshed.
  ApiResult<bool> refresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) {
      return Failure(ApiError.loginRequired);
    }
    try {
      final resp = await dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {'skipAuthInterceptor': true}),
      );
      final data = _normalizeResp(resp);
      _persistTokens(data);
      return Success(true);
    } on DioException catch (e) {
      return Failure(_wrapDioException(e));
    }
  }

  // /// Optional register helper for admin usage
  // Future<void> register(String username, String password) async {
  //   try {
  //     await dio.post(
  //       '/admin/register',
  //       data: {'username': username, 'password': password},
  //       options: Options(extra: {'skipAuthInterceptor': true}),
  //     );
  //   } on DioException catch (e) {
  //     throw _wrapDioException(e);
  //   }
  // }

  void _persistTokens(Map<String, dynamic> data) {
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    // server may send expiry seconds or expiry timestamp
    // DateTime? accessExpiry;
    // if (data.containsKey('expires_in')) {
    //   final expires = data['expires_in'];
    //   if (expires is int) accessExpiry = DateTime.now().add(Duration(seconds: expires));
    // }
    if (access != null) {
      _storage.setAccessToken(access);
    }
    if (refresh != null) {
      _storage.setRefreshToken(refresh);
    }
  }

  Map<String, dynamic> _normalizeResp(Response resp) {
    if (resp.data is Map<String, dynamic>) return resp.data as Map<String, dynamic>;
    return {'raw': resp.data};
  }
}

ApiError _wrapDioException(DioException e) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout) {
    return ApiError.networkError;
  }
  if (e.type == DioExceptionType.unknown && e.error is ApiError) {
    return e.error as ApiError;
  }
  if (e.response != null) {
    final status = e.response!.statusCode ?? 0;
    final data = e.response!.data;
    print('Error with response data: $data');
    if (status == 401) return ApiError.loginRequired;
    if (status == 403) return ApiError.permissionDenied;
    if (status == 400) return ApiError.validationError;
  }
  return ApiError.unknown;
}
