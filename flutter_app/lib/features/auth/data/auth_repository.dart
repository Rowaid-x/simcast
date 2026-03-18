import '../../../core/storage/secure_storage.dart';
import '../../../models/user.dart';
import 'auth_api.dart';

/// Repository that coordinates auth API calls and secure token storage.
class AuthRepository {
  final AuthApi _api;

  AuthRepository(this._api);

  /// Register a new account, store tokens, and return the user.
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final data = await _api.register(
      email: email,
      password: password,
      displayName: displayName,
    );

    final tokens = data['tokens'] as Map<String, dynamic>;
    await SecureStorage.saveTokens(
      accessToken: tokens['access'],
      refreshToken: tokens['refresh'],
    );

    final user = User.fromJson(data['user']);
    await SecureStorage.setUserId(user.id);
    return user;
  }

  /// Log in, store tokens, and return the user.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.login(email: email, password: password);

    final tokens = data['tokens'] as Map<String, dynamic>;
    await SecureStorage.saveTokens(
      accessToken: tokens['access'],
      refreshToken: tokens['refresh'],
    );

    final user = User.fromJson(data['user']);
    await SecureStorage.setUserId(user.id);
    return user;
  }

  /// Log out and clear stored tokens.
  Future<void> logout() async {
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken != null) {
        await _api.logout(refreshToken);
      }
    } catch (_) {
      // Ignore errors during logout — clear tokens regardless
    } finally {
      await SecureStorage.clearAll();
    }
  }

  /// Change password.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _api.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  /// Check if user has stored tokens.
  Future<bool> isLoggedIn() async {
    return await SecureStorage.hasTokens();
  }
}
