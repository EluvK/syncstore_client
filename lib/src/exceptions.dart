class ApiException implements Exception {
  final String message;
  ApiException([this.message = 'ApiException']);
  @override
  String toString() => 'ApiException: $message';
}

class AuthException extends ApiException {
  AuthException([String message = 'AuthException']) : super(message);
}

class ValidationException extends ApiException {
  ValidationException([String message = 'ValidationException']) : super(message);
}

class NetworkException extends ApiException {
  NetworkException([String message = 'NetworkException']) : super(message);
}