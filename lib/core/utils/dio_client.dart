// lib/core/utils/dio_client.dart
// Singleton Dio client with structured logging + error interceptors.

import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/foundation.dart';
import '../errors/app_exception.dart';

class DioClient {
  DioClient._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    
    // Enable HTTP/2 for better performance (multiplexing)
    _dio.httpClientAdapter = Http2Adapter(
      ConnectionManager(
        idleTimeout: const Duration(seconds: 15),
        onClientCreate: (_, config) => config.onBadCertificate = (_) => true, // Only for debugging if needed
      ),
    );

    _dio.interceptors.addAll([
      _LoggingInterceptor(),
      _ErrorInterceptor(),
    ]);
  }

  static final DioClient _instance = DioClient._();
  static DioClient get instance => _instance;

  late final Dio _dio;
  Dio get dio => _dio;
}

// ── Logging Interceptor ───────────────────────────────────────────

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) debugPrint('[DIO →] ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[DIO ←] ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
          '[DIO ✗] ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}');
    }
    handler.next(err);
  }
}

// ── Error Interceptor ─────────────────────────────────────────────
// Maps DioExceptions to typed AppExceptions before they reach the repository.

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.connectionError =>
        const NetworkException(),
      DioExceptionType.badResponse => _mapStatusCode(err),
      DioExceptionType.cancel =>
        const ServerException('Request was cancelled.'),
      _ => NetworkException(err.message ?? 'Unknown network error.'),
    };

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: appException,
        type: err.type,
        response: err.response,
      ),
    );
  }

  AppException _mapStatusCode(DioException err) {
    final code = err.response?.statusCode ?? 0;
    return switch (code) {
      404 => const NotFoundException(),
      401 ||
      403 =>
        ServerException('Unauthorized (HTTP $code).', statusCode: code),
      >= 500 => ServerException('Server error (HTTP $code).', statusCode: code),
      _ =>
        ServerException('Request failed with status $code.', statusCode: code),
    };
  }
}
