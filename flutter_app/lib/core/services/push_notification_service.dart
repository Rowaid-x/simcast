import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';
import '../network/api_client.dart';

/// Background message handler — must be top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  // Background messages can be processed here if needed
}

/// Service for managing FCM push notifications.
class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize push notifications — request permissions, get token, register handlers.
  void _log(Ref ref, String msg) {
    debugPrint('[Push] $msg');
    ref.read(pushDebugLogProvider.notifier).update((s) => [...s, msg]);
  }

  Future<void> initialize(Ref ref) async {
    _log(ref, 'Starting push init...');

    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS/macOS)
    _log(ref, 'Requesting permissions...');
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _log(ref, 'Auth status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // On iOS, wait for APNs token before requesting FCM token
      if (Platform.isIOS) {
        _log(ref, 'iOS: waiting for APNs token...');
        String? apnsToken;
        for (int i = 0; i < 10; i++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
        _log(ref, apnsToken != null ? 'APNs token OK' : 'APNs token still null after 10s');
      }

      // Get FCM token
      try {
        _log(ref, 'Getting FCM token...');
        final token = await _messaging.getToken();
        if (token != null) {
          _log(ref, 'Token: ${token.substring(0, 20)}...');
          await _registerDeviceToken(ref, token);
        } else {
          _log(ref, 'ERROR: Token is NULL');
        }
      } catch (e) {
        _log(ref, 'ERROR getting token: $e');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _log(ref, 'Token refreshed, re-registering...');
        _registerDeviceToken(ref, newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a terminated state notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } else {
      _log(ref, 'NOT authorized: ${settings.authorizationStatus}');
    }
  }

  /// Register the device FCM token with the backend.
  Future<void> _registerDeviceToken(Ref ref, String token) async {
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.post('/users/me/device-token/', data: {
        'device_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
      _log(ref, 'Token registered! (${response.statusCode})');
    } catch (e) {
      _log(ref, 'ERROR registering token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // In foreground, we rely on WebSocket for real-time updates.
    // Could show a local notification banner here if desired.
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Extract conversation_id from data payload to navigate to chat
    final data = message.data;
    final conversationId = data['conversation_id'];
    if (conversationId != null) {
      // Navigation would be handled by the router — store pending route
      _pendingConversationId = conversationId;
    }
  }

  /// Pending conversation ID from a notification tap (to navigate after app loads).
  String? _pendingConversationId;

  /// Consume the pending conversation ID (call once after router is ready).
  String? consumePendingConversationId() {
    final id = _pendingConversationId;
    _pendingConversationId = null;
    return id;
  }
}

/// Debug log for push notification status (visible in UI temporarily).
final pushDebugLogProvider = StateProvider<List<String>>((ref) => []);

/// Global push notification service provider.
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});
