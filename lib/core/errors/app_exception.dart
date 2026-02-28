// lib/core/errors/app_exception.dart

/// Typed exceptions for the Currenta app.
/// All repository/datasource calls should throw these instead of raw exceptions.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Network is unavailable or the request timed out.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'No internet connection. Please check your network.',
  ]);
}

/// The remote server returned a non-2xx status code.
class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode});
  final int? statusCode;
}

/// Local database operation failed.
class CacheException extends AppException {
  const CacheException([
    super.message = 'Failed to read from local cache.',
  ]);
}

/// LLM provider returned an unexpected or malformed response.
class LlmException extends AppException {
  const LlmException(super.message);
}

/// Resource was not found (404-style).
class NotFoundException extends AppException {
  const NotFoundException([
    super.message = 'The requested resource was not found.',
  ]);
}
