import 'package:flutter/foundation.dart';

/// Typed exceptions for the Currenta app.
/// All repository/datasource calls should throw these instead of raw exceptions.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  /// Returns a user-friendly message for UI display.
  /// In release mode, technical details are hidden.
  String get displayMessage {
    if (kReleaseMode) {
      if (this is NetworkException || this is AuthActionException) {
        return message;
      }
      return 'Something went wrong. Please try again.';
    }
    return message;
  }

  @override
  String toString() => message;
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

/// Authentication related errors that are safe to show to the user.
class AuthActionException extends AppException {
  const AuthActionException(super.message);
}

/// Extension to provide consistent user-friendly error messages across the app.
extension ErrorFormatter on Object {
  String toDisplayMessage() {
    if (this is AppException) {
      return (this as AppException).displayMessage;
    }
    
    if (kReleaseMode) {
      // In release mode, any unexpected system error shows the generic message.
      return 'Something went wrong. Please try again.';
    }
    
    // In debug mode, show the original error for troubleshooting.
    return toString();
  }
}
