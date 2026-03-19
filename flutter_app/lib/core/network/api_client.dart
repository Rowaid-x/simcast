import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../storage/secure_storage.dart';

/// Dio HTTP client provider with JWT token interceptor.
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(LogInterceptor(
    requestBody: false,
    responseBody: true,
    logPrint: (o) => debugPrint('[Dio] $o'),
  ));
  dio.interceptors.add(JwtInterceptor(dio));
  return dio;
});

/// Interceptor that attaches JWT access tokens and handles automatic refresh.
class JwtInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;
  final List<_RetryRequest> _pendingRequests = [];

  JwtInterceptor(this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for login/register/refresh endpoints
    final noAuthPaths = ['/auth/login/', '/auth/register/', '/auth/token/refresh/'];
    if (noAuthPaths.any((path) => options.path.contains(path))) {
      return handler.next(options);
    }

    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Don't retry refresh token requests
    if (err.requestOptions.path.contains('/auth/token/refresh/')) {
      await SecureStorage.clearAll();
      return handler.next(err);
    }

    if (_isRefreshing) {
      // Queue this request to retry after refresh completes
      _pendingRequests.add(_RetryRequest(err.requestOptions, handler));
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null) {
        await SecureStorage.clearAll();
        return handler.next(err);
      }

      // Attempt token refresh
      final refreshDio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        headers: {'Content-Type': 'application/json'},
      ));

      final response = await refreshDio.post(
        '/auth/token/refresh/',
        data: {'refresh': refreshToken},
      );

      final newAccess = response.data['access'] as String;
      final newRefresh = response.data['refresh'] as String;

      await SecureStorage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );

      // Retry the original request
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _dio.fetch(retryOptions);
      handler.resolve(retryResponse);

      // Retry all queued requests
      for (final pending in _pendingRequests) {
        pending.options.headers['Authorization'] = 'Bearer $newAccess';
        try {
          final resp = await _dio.fetch(pending.options);
          pending.handler.resolve(resp);
        } catch (e) {
          pending.handler.reject(
            DioException(requestOptions: pending.options, error: e),
          );
        }
      }
      _pendingRequests.clear();
    } on DioException {
      // Refresh failed — clear tokens and reject
      await SecureStorage.clearAll();
      handler.next(err);
      for (final pending in _pendingRequests) {
        pending.handler.next(
          DioException(requestOptions: pending.options, error: 'Session expired'),
        );
      }
      _pendingRequests.clear();
    } finally {
      _isRefreshing = false;
    }
  }
}

class _RetryRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  _RetryRequest(this.options, this.handler);
}
