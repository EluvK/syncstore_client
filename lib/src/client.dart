import 'package:dio/dio.dart';
import 'auth_interceptor.dart';
import 'token_storage.dart';
import 'models.dart';
import 'errors.dart';

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

  Future<bool> login(String username, String password) {
    return authService.login(username, password);
  }

  Future<bool> logout() async {
    // Just clear tokens, todo might need to call server logout endpoint in future
    await tokenStorage.clear();
    return true;
  }

  /// create new data, returns meta id
  Future<String> create(String namespace, String collection, Map<String, dynamic> body) {
    return perform(() async {
      final resp = await _dio.post('/data/$namespace/$collection', data: body);
      return resp.data as String;
    });
  }

  /// get data by id
  Future<T> get<T extends Object>(
      String namespace, String collection, String id, T Function(Map<String, dynamic>) fromJson) {
    return perform(() async {
      final resp = await _dio.get('/data/$namespace/$collection/$id');
      return fromJson(resp.data as Map<String, dynamic>);
    });
  }

  /// update data by id
  Future<String> update(String namespace, String collection, String id, Map<String, dynamic> body) {
    return perform(() async {
      final resp = await _dio.post('/data/$namespace/$collection/$id', data: body);
      return resp.data as String;
    });
  }

  Future<void> delete(String namespace, String collection, String id) {
    return perform(() async {
      await _dio.delete('/data/$namespace/$collection/$id');
    });
  }

  /// list with optional parentId, marker, limit
  Future<ListResponse<T>> list<T>(
    String namespace,
    String collection, {
    String? parentId,
    String? marker,
    int limit = 50,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    return perform(() async {
      final query = <String, dynamic>{
        if (parentId != null) 'parent_id': parentId,
        if (marker != null) 'marker': marker,
        'limit': limit,
      };

      final resp = await _dio.get('/data/$namespace/$collection', queryParameters: query);
      final data = resp.data as Map<String, dynamic>;

      final fromJsonT = (Object? json) => fromJson(json as Map<String, dynamic>);

      return ListResponse<T>.fromJson(data, fromJsonT);
    });
  }
}

class AuthService {
  final Dio dio;
  final TokenStorage _storage;

  AuthService(this.dio, this._storage);

  Future<bool> login(String username, String password) {
    return perform(() async {
      final resp = await dio.post(
        '/auth/name-login',
        data: {'username': username, 'password': password},
        options: Options(extra: {'skipAuthInterceptor': true}),
      );
      final data = _normalizeResp(resp);
      _persistTokens(data);
      return true;
    });
  }

  Future<bool> refresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) {
      throw ApiException(ApiError.loginRequired);
    }

    return perform(() async {
      final resp = await dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {'skipAuthInterceptor': true}),
      );
      final data = _normalizeResp(resp);
      _persistTokens(data);
      return true;
    });
  }

  void _persistTokens(Map<String, dynamic> data) {
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;

    if (access != null) _storage.setAccessToken(access);
    if (refresh != null) _storage.setRefreshToken(refresh);
  }

  Map<String, dynamic> _normalizeResp(Response resp) {
    if (resp.data is Map<String, dynamic>) {
      return resp.data as Map<String, dynamic>;
    }
    return {'raw': resp.data};
  }
}

ApiException _wrapDioException(DioException e) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout) {
    return ApiException(ApiError.networkError);
  }
  if (e.type == DioExceptionType.unknown && e.error is ApiError) {
    return ApiException(e.error as ApiError);
  }
  if (e.response != null) {
    final status = e.response!.statusCode ?? 0;
    final data = e.response!.data;
    print('Error with response data: $data');
    if (status == 401) return ApiException(ApiError.loginRequired);
    if (status == 403) return ApiException(ApiError.permissionDenied);
    if (status == 400) return ApiException(ApiError.validationError);
  }
  return ApiException(ApiError.unknown);
}

/// Universal wrapper
Future<T> perform<T>(Future<T> Function() f) async {
  try {
    return await f();
  } on DioException catch (e) {
    throw _wrapDioException(e);
  }
}
