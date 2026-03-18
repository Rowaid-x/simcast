import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/websocket_client.dart';

/// Provider that exposes the WebSocket connection state stream.
final wsConnectionStateProvider =
    StreamProvider<WsConnectionState>((ref) {
  final client = ref.watch(webSocketClientProvider);
  return client.stateStream;
});

/// Provider that exposes all incoming WebSocket messages as a stream.
final wsMessageStreamProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final client = ref.watch(webSocketClientProvider);
  return client.messageStream;
});

/// Provider for online user IDs tracked via WebSocket events.
final onlineUsersProvider =
    StateNotifierProvider<OnlineUsersNotifier, Set<String>>(
  (ref) {
    final notifier = OnlineUsersNotifier();
    final client = ref.watch(webSocketClientProvider);

    final subscription = client.messageStream.listen((message) {
      final type = message['type'] as String?;
      if (type == 'user.online') {
        final userId = message['user_id'] as String?;
        final isOnline = message['is_online'] as bool? ?? false;
        if (userId != null) {
          if (isOnline) {
            notifier.setOnline(userId);
          } else {
            notifier.setOffline(userId);
          }
        }
      }
    });

    ref.onDispose(() => subscription.cancel());
    return notifier;
  },
);

/// Notifier tracking which users are currently online.
class OnlineUsersNotifier extends StateNotifier<Set<String>> {
  OnlineUsersNotifier() : super({});

  void setOnline(String userId) {
    state = {...state, userId};
  }

  void setOffline(String userId) {
    state = {...state}..remove(userId);
  }

  bool isOnline(String userId) => state.contains(userId);
}
