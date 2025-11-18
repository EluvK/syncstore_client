import 'package:result_dart/result_dart.dart';

enum ApiError {
  // 403 forbidden
  permissionDenied,
  // 401 unauthorized, should login again
  loginRequired,
  // 400 bad request, validation error, usually data schema issue
  validationError,
  // network error, e.g. no internet connection
  networkError,
  // unknown error
  unknown,
}

typedef ApiResult<T extends Object> = AsyncResultDart<T, ApiError>;
