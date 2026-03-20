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
  Future<void> initialize(Ref ref) async {
    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS/macOS)
    debugPrint('[Push] Requesting notification permissions...');
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[Push] Authorization status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Get FCM token
      try {
        final token = await _messaging.getToken();
        debugPrint('[Push] FCM token: ${token != null ? '${token.substring(0, 20)}...' : 'NULL'}');
        if (token != null) {
          await _registerDeviceToken(ref, token);
        } else {
          debugPrint('[Push] ERROR: FCM token is null — APNs may not be configured');
        }
      } catch (e) {
        debugPrint('[Push] ERROR getting FCM token: $e');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[Push] Token refreshed, re-registering...');
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
      debugPrint('[Push] Notifications NOT authorized — status: ${settings.authorizationStatus}');
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
      debugPrint('[Push] Device token registered successfully: ${response.statusCode}');
    } catch (e) {
      debugPrint('[Push] ERROR registering device token: $e');
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

/// Global push notification service provider.
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});
