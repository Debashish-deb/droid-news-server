import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../../core/telemetry/structured_logger.dart';
import '../../core/security/certificate_pinner.dart';
import 'package:injectable/injectable.dart';

/// A unified Dio client with interceptors for Logging, Auth, and Retry.
/// Also implements SSL Pinning.
@lazySingleton
class InterceptedDioClient {

  InterceptedDioClient() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ));

    _addInterceptors();
    _setupSslPinning();
  }
  late final Dio dio;
  final _logger = StructuredLogger();

  void _addInterceptors() {
    // 1. Logging Interceptor
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        _logger.info('Dio Request: [${options.method}] ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.info('Dio Response: [${response.statusCode}] ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        _logger.error('Dio Error: [${e.response?.statusCode}] ${e.requestOptions.uri}', e);
        return handler.next(e);
      },
    ));

    // 2. Retry Interceptor (Basic implementation)
    dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) async {
        if (_shouldRetry(e)) {
          try {
            final response = await _retry(e.requestOptions);
            return handler.resolve(response);
          } catch (retryError) {
            return handler.next(e);
          }
        }
        return handler.next(e);
      },
    ));

    // 3. Auth Interceptor (Placeholder for token refresh)
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // TODO: Inject Auth token from AuthFacade
        // options.headers['Authorization'] = 'Bearer $token';
        return handler.next(options);
      },
    ));
  }

  bool _shouldRetry(DioException e) {
    return e.type != DioExceptionType.cancel &&
        e.type != DioExceptionType.badResponse &&
        e.error is! SocketException;
  }

  Future<Response> _retry(RequestOptions requestOptions) {
    return dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: Options(
        method: requestOptions.method,
        headers: requestOptions.headers,
      ),
    );
  }

  void _setupSslPinning() {
    // Only enable SSL Pinning in production/real devices if certificates are present
    if (kReleaseMode) {
       (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) {
          return CertificatePinner.verifyFingerprint(cert);
        };
        return client;
      };
    }
  }
}
