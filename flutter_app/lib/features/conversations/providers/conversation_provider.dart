import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_client.dart';
import '../../../models/conversation.dart';
import '../../../models/message.dart';
import '../../../models/user.dart';
import '../data/conversation_api.dart';
import '../data/conversation_repository.dart';

/// Provider for the ConversationRepository.
final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return ConversationRepository(ConversationApi(dio));
});

/// Tracks the conversation ID the user currently has open.
/// Set when entering a chat, cleared when leaving.
final activeConversationIdProvider = StateProvider<String?>((ref) => null);

/// Provider for the conversations list with real-time updates.
final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
  ConversationsNotifier.new,
);

/// Notifier managing the conversations list state.
class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  StreamSubscription? _wsSubscription;

  @override
  Future<List<Conversation>> build() async {
    final repo = ref.read(conversationRepositoryProvider);
    final conversations = await repo.getConversations();

    // Listen for WebSocket events to update conversation list
    _wsSubscription?.cancel();
    final wsClient = ref.read(webSocketClientProvider);
    _wsSubscription = wsClient.messageStream.listen(_handleWsMessage);

    ref.onDispose(() => _wsSubscription?.cancel());

    return conversations;
  }

  void _handleWsMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == 'chat.message') {
      _handleNewMessage(message['message']);
    }
  }

  void _handleNewMessage(Map<String, dynamic>? messageData) {
    if (messageData == null) return;
    final msg = Message.fromJson(messageData);
    final currentList = state.valueOrNull ?? [];
    final activeConvId = ref.read(activeConversationIdProvider);

    final updatedList = currentList.map((conv) {
      if (conv.id == msg.conversationId) {
        return conv.copyWith(
          lastMessage: msg,
          unreadCount: conv.id == activeConvId
              ? 0
              : conv.unreadCount + 1,
        );
      }
      return conv;
    }).toList();

    // Sort by most recent message
    updatedList.sort((a, b) {
      final aTime = a.lastMessage?.createdAt ?? a.updatedAt;
      final bTime = b.lastMessage?.createdAt ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });

    state = AsyncData(updatedList);
  }

  /// Refresh the conversations list from the server.
  Future<void> refresh() async {
    final repo = ref.read(conversationRepositoryProvider);
    final conversations = await repo.getConversations();
    state = AsyncData(conversations);
  }

  /// Create a new direct conversation and add it to the list.
  Future<Conversation> createDirect(String userId) async {
    final repo = ref.read(conversationRepositoryProvider);
    final conversation = await repo.createDirectConversation(userId);

    final currentList = state.valueOrNull ?? [];
    // Check if already exists
    if (!currentList.any((c) => c.id == conversation.id)) {
      state = AsyncData([conversation, ...currentList]);
    }
    return conversation;
  }

  /// Create a new group conversation and add it to the list.
  Future<Conversation> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final repo = ref.read(conversationRepositoryProvider);
    final conversation = await repo.createGroupConversation(
      name: name,
      memberIds: memberIds,
    );

    final currentList = state.valueOrNull ?? [];
    state = AsyncData([conversation, ...currentList]);
    return conversation;
  }

  /// Mark a conversation's unread count as 0.
  void markAsRead(String conversationId) {
    final currentList = state.valueOrNull ?? [];
    final updated = currentList.map((conv) {
      if (conv.id == conversationId) {
        return conv.copyWith(unreadCount: 0);
      }
      return conv;
    }).toList();
    state = AsyncData(updated);
  }
}

/// Provider for user search results.
final userSearchProvider =
    FutureProvider.family<List<User>, String>((ref, query) async {
  if (query.length < 2) return [];
  final repo = ref.read(conversationRepositoryProvider);
  return repo.searchUsers(query);
});
