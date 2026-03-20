import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../models/user.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';

/// Provider for the AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return AuthRepository(AuthApi(dio));
});

/// Auth state provider — holds the current user or null.
final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

/// Notifier that manages authentication state.
class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    // Check if user has stored tokens on app start
    final hasTokens = await SecureStorage.hasTokens();
    if (!hasTokens) return null;

    // Try to fetch current user profile to validate tokens
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get('/users/me/');
      final user = User.fromJson(response.data);

      // Connect WebSocket on successful auth
      ref.read(webSocketClientProvider).connect();

      // Initialize push notifications (don't block auth)
      _initPushNotifications();

      return user;
    } catch (_) {
      // Tokens invalid — clear and return null
      await SecureStorage.clearAll();
      return null;
    }
  }

  /// Register a new account.
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      ref.read(webSocketClientProvider).connect();
      _initPushNotifications();
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Log in with email and password.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.login(email: email, password: password);
      ref.read(webSocketClientProvider).connect();
      _initPushNotifications();
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Log out and disconnect WebSocket.
  Future<void> logout() async {
    ref.read(webSocketClientProvider).disconnect();
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncData(null);
  }

  /// Update the user profile locally (after API update).
  void updateUser(User user) {
    state = AsyncData(user);
  }

  void _initPushNotifications() {
    debugPrint('[Push] _initPushNotifications called');
    ref
        .read(pushNotificationServiceProvider)
        .initialize(ref)
        .then((_) => debugPrint('[Push] initialization completed'))
        .catchError((e) {
      debugPrint('[Push] _initPushNotifications error: $e');
    });
  }
}
