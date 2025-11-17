import 'dart:async';
import 'package:dio/dio.dart';
import 'token_storage.dart';
import 'auth_service.dart';
import 'exceptions.dart';

/// AuthInterceptor automatically attaches Authorization header and
/// retries requests when access token expired by running refresh once.
///
/// Usage:
///  final dio = Dio(BaseOptions(baseUrl: 'http://.../api'));
///  final storage = InMemoryTokenStorage();
///  final authService = AuthService(dio, storage);
///  dio.interceptors.add(AuthInterceptor(storage, authService));
class AuthInterceptor extends Interceptor {
  final TokenStorage _storage;
  final AuthService _authService;

  // Single refresh completer to deduplicate concurrent refresh requests.
  Completer<bool>? _refreshCompleter;

  AuthInterceptor(this._storage, this._authService);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // ignore storage errors for now
    }
    handler.next(options);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    // only attempt refresh on 401 and for non-retried requests
    final requestOptions = err.requestOptions;
    final alreadyRetried = requestOptions.extra['__retried'] == true;

    if (status == 401 && !alreadyRetried) {
      try {
        final didRefresh = await _runRefresh();
        if (didRefresh) {
          // update headers and retry
          final newToken = await _storage.getAccessToken();
          if (newToken == null) {
            handler.next(err);
            return;
          }
          final opts = Options(
            method: requestOptions.method,
            headers: Map<String, dynamic>.from(requestOptions.headers ?? {})..['Authorization'] = 'Bearer $newToken',
          );
          final cloneReq = await _authService.dio.request(
            requestOptions.path,
            data: requestOptions.data,
            queryParameters: requestOptions.queryParameters,
            options: opts..extra?.addAll({'__retried': true}),
            cancelToken: requestOptions.cancelToken,
            onReceiveProgress: requestOptions.onReceiveProgress,
            onSendProgress: requestOptions.onSendProgress,
          );
          return handler.resolve(cloneReq);
        } else {
          // refresh failed: clear storage and raise AuthException
          await _storage.clear();
          handler.next(
              DioError(requestOptions: requestOptions, error: AuthException('Token refresh failed'), type: err.type));
          return;
        }
      } catch (e) {
        await _storage.clear();
        handler.next(DioError(requestOptions: requestOptions, error: AuthException('Token refresh failed: $e')));
        return;
      }
    }

    handler.next(err);
  }

  Future<bool> _runRefresh() async {
    if (_refreshCompleter != null) {
      // another refresh in progress - wait for it
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<bool>();
    try {
      final ok = await _authService.refresh();
      _refreshCompleter!.complete(ok);
      return ok;
    } catch (e) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      // allow a short delay before nulling to reduce races (optional)
      Future.delayed(Duration(milliseconds: 10), () {
        _refreshCompleter = null;
      });
    }
  }
}
