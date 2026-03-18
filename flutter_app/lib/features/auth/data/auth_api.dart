import 'package:dio/dio.dart';

/// API service for authentication endpoints.
class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  /// Register a new user account.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _dio.post('/auth/register/', data: {
      'email': email,
      'password': password,
      'password_confirm': password,
      'display_name': displayName,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Log in with email and password.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login/', data: {
      'email': email,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Refresh access token using a refresh token.
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _dio.post('/auth/token/refresh/', data: {
      'refresh': refreshToken,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Log out by blacklisting the refresh token.
  Future<void> logout(String refreshToken) async {
    await _dio.post('/auth/logout/', data: {
      'refresh': refreshToken,
    });
  }

  /// Change the current user's password.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.post('/auth/change-password/', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }
}
