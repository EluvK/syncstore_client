import 'package:dio/dio.dart';
import 'auth_interceptor.dart';
import 'auth_service.dart';
import 'token_storage.dart';
import 'models.dart';
import 'exceptions.dart';

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
  Future<T> create<T>(String namespace, String collection, Map<String, dynamic> body,
      T Function(Map<String, dynamic>) fromMap) async {
    try {
      final resp = await _dio.post('/$namespace/$collection', data: body);
      final data = resp.data as Map<String, dynamic>;
      return fromMap(data);
    } on DioError catch (e) {
      throw _wrapDioError(e);
    }
  }

  Future<T> get<T>(String namespace, String collection, String id, T Function(Map<String, dynamic>) fromMap) async {
    try {
      final resp = await _dio.get('/$namespace/$collection/$id');
      final data = resp.data as Map<String, dynamic>;
      return fromMap(data);
    } on DioError catch (e) {
      throw _wrapDioError(e);
    }
  }

  Future<T> update<T>(String namespace, String collection, String id, Map<String, dynamic> body,
      T Function(Map<String, dynamic>) fromMap) async {
    try {
      final resp = await _dio.post('/$namespace/$collection/$id', data: body);
      final data = resp.data as Map<String, dynamic>;
      return fromMap(data);
    } on DioError catch (e) {
      throw _wrapDioError(e);
    }
  }

  Future<void> delete(String namespace, String collection, String id) async {
    try {
      await _dio.delete('/$namespace/$collection/$id');
    } on DioError catch (e) {
      throw _wrapDioError(e);
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
      final resp = await _dio.get('/$namespace/$collection', queryParameters: query);
      final data = resp.data as Map<String, dynamic>;
      return ListResponse.fromMap(data, fromMap);
    } on DioError catch (e) {
      throw _wrapDioError(e);
    }
  }

  ApiException _wrapDioError(DioError e) {
    if (e.type == DioErrorType.connectionTimeout ||
        e.type == DioErrorType.receiveTimeout ||
        e.type == DioErrorType.sendTimeout) {
      return NetworkException('Network timeout: ${e.message}');
    }
    if (e.response != null) {
      final status = e.response!.statusCode ?? 0;
      final data = e.response!.data;
      if (status == 401) return AuthException('Unauthorized');
      if (status == 400) return ValidationException(data?.toString() ?? 'Bad request');
      return ApiException('HTTP $status: ${e.message}');
    }
    return ApiException(e.message ?? 'Unknown Dio error');
  }
}