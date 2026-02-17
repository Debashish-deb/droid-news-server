// lib/infrastructure/network/intercepted_dio_client.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../../core/telemetry/structured_logger.dart';
import '../../core/security/certificate_pinner.dart';
import '../../domain/facades/auth_facade.dart';


class InterceptedDioClient {
  static const int _maxRetries = 3;

  InterceptedDioClient(this._auth) {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ));

    _addInterceptors();
    _setupSslPinning();
  }
  
  final AuthFacade _auth;
  
  late final Dio dio;
  final _logger = StructuredLogger();

  void _addInterceptors() {
    // 1. Auth Interceptor: Securely injects Firebase Auth Token
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          if (_auth.isLoggedIn) {
            // getIdToken() automatically handles token refresh if expired
            final token = await _auth.currentUser?.getIdToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
        } catch (e) {
          _logger.warning('Failed to inject auth token', e);
        }
        return handler.next(options);
      },
    ));

    // 2. Logging Interceptor
    dio.interceptors.add(LogInterceptor(
      requestHeader: true,
      requestBody: kDebugMode,
      responseHeader: false,
    ));

    // 3. Resilience Interceptor: Adds exponential backoff retry with limits
    dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) async {
        int retryCount = (e.requestOptions.extra['retries'] ?? 0) as int;
        
        if (_shouldRetry(e) && retryCount < _maxRetries) {
          retryCount++;
          e.requestOptions.extra['retries'] = retryCount;
          
          _logger.info('Retrying request [${retryCount}/$_maxRetries]: ${e.requestOptions.uri}');
          
          // Wait before retrying (exponential backoff)
          await Future.delayed(Duration(seconds: retryCount * 2));
          
          try {
            final response = await dio.fetch(e.requestOptions);
            return handler.resolve(response);
          } catch (retryError) {
            return handler.next(e);
          }
        }
        return handler.next(e);
      },
    ));
  }

  bool _shouldRetry(DioException e) {
    // Don't retry if the user cancelled or if the server explicitly rejected the data (4xx)
    return e.type != DioExceptionType.cancel &&
           e.type != DioExceptionType.badResponse &&
           e.error is! SocketException;
  }

  void _setupSslPinning() {
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