import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/constants.dart';

/// Wrapper around flutter_secure_storage for secure token management.
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // --- Access Token ---

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.accessTokenKey);
  }

  static Future<void> setAccessToken(String token) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: token);
  }

  // --- Refresh Token ---

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.refreshTokenKey);
  }

  static Future<void> setRefreshToken(String token) async {
    await _storage.write(key: AppConstants.refreshTokenKey, value: token);
  }

  // --- User ID ---

  static Future<String?> getUserId() async {
    return await _storage.read(key: AppConstants.userIdKey);
  }

  static Future<void> setUserId(String userId) async {
    await _storage.write(key: AppConstants.userIdKey, value: userId);
  }

  // --- Tokens pair ---

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      setAccessToken(accessToken),
      setRefreshToken(refreshToken),
    ]);
  }

  // --- Clear all ---

  static Future<void> clearAll() async {
    // Preserve saved credentials across logout
    final email = await getSavedEmail();
    final password = await getSavedPassword();
    await _storage.deleteAll();
    if (email != null) {
      await _storage.write(key: AppConstants.savedEmailKey, value: email);
    }
    if (password != null) {
      await _storage.write(key: AppConstants.savedPasswordKey, value: password);
    }
  }

  /// Check if user has stored tokens (potentially logged in).
  static Future<bool> hasTokens() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();
    return access != null && refresh != null;
  }

  // --- Saved Credentials ---

  static Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.savedEmailKey, value: email),
      _storage.write(key: AppConstants.savedPasswordKey, value: password),
    ]);
  }

  static Future<String?> getSavedEmail() async {
    return await _storage.read(key: AppConstants.savedEmailKey);
  }

  static Future<String?> getSavedPassword() async {
    return await _storage.read(key: AppConstants.savedPasswordKey);
  }

  static Future<bool> hasSavedCredentials() async {
    final email = await getSavedEmail();
    return email != null && email.isNotEmpty;
  }

  static Future<void> clearCredentials() async {
    await Future.wait([
      _storage.delete(key: AppConstants.savedEmailKey),
      _storage.delete(key: AppConstants.savedPasswordKey),
    ]);
  }
}
