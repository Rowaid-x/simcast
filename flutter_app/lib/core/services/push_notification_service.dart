import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Background message handler — must be top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages can be processed here if needed
}

/// Service for managing FCM push notifications.
class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize push notifications — request permissions, get token, register handlers.
  Future<void> initialize(WidgetRef ref) async {
    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS/macOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Get FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        await _registerDeviceToken(ref, token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
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
    }
  }

  /// Register the device FCM token with the backend.
  Future<void> _registerDeviceToken(WidgetRef ref, String token) async {
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post('/users/me/device-token/', data: {
        'device_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (_) {
      // Silently fail — token will be retried on refresh
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
