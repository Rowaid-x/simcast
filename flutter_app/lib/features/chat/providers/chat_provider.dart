import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../models/message.dart';
import '../../../models/user.dart';
import '../../conversations/providers/conversation_provider.dart';
import '../data/message_api.dart';
import '../data/message_repository.dart';

const _uuid = Uuid();

/// In-memory cache so re-opening a conversation shows messages instantly.
final _messageCache = <String, List<Message>>{};

/// Provider for the MessageRepository.
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return MessageRepository(MessageApi(dio));
});

/// Chat state holding messages and metadata for a conversation.
class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool hasMore;
  final String? nextCursor;
  final String? error;
  final Map<String, bool> typingUsers;
  final int? autoDeleteTimer;
  final bool timerUpdated;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.nextCursor,
    this.error,
    this.typingUsers = const {},
    this.autoDeleteTimer,
    this.timerUpdated = false,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? hasMore,
    String? nextCursor,
    String? error,
    Map<String, bool>? typingUsers,
    int? autoDeleteTimer,
    bool? timerUpdated,
    bool clearTimer = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: error,
      typingUsers: typingUsers ?? this.typingUsers,
      autoDeleteTimer: clearTimer ? null : (autoDeleteTimer ?? this.autoDeleteTimer),
      timerUpdated: timerUpdated ?? this.timerUpdated,
    );
  }
}

/// Provider family for per-conversation chat state.
/// Uses autoDispose so state is fresh each time the chat screen is opened.
final chatProvider =
    StateNotifierProvider.autoDispose.family<ChatNotifier, ChatState, String>(
  (ref, conversationId) => ChatNotifier(ref, conversationId),
);

/// Notifier managing chat messages for a specific conversation.
class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  final String conversationId;
  StreamSubscription? _wsSubscription;
  Timer? _typingTimer;
  bool _isTypingSent = false;

  ChatNotifier(this._ref, this.conversationId)
      : super(ChatState(
          messages: _messageCache[conversationId] ?? const [],
          isLoading: true,
        )) {
    _subscribeToWebSocket();
    Future.microtask(() => _loadInitialMessages());
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  /// Refresh messages (for pull-to-refresh).
  Future<void> refresh() async {
    await _loadInitialMessages();
  }

  /// Load the first page of messages.
  Future<void> _loadInitialMessages() async {
    if (!mounted) return;
    if (_messageCache[conversationId] == null) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final repo = _ref.read(messageRepositoryProvider);
      final page = await repo.getMessages(conversationId, pageSize: 50);
      if (!mounted) return;
      _messageCache[conversationId] = page.messages;
      state = state.copyWith(
        messages: page.messages,
        isLoading: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load messages',
      );
    }
  }

  /// Load more (older) messages for infinite scroll.
  Future<void> loadMore() async {
    if (!mounted || state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(messageRepositoryProvider);
      final page = await repo.getMessages(
        conversationId,
        cursor: state.nextCursor,
      );
      if (!mounted) return;
      state = state.copyWith(
        messages: [...state.messages, ...page.messages],
        isLoading: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  /// Send a text message via WebSocket (with REST fallback).
  Future<void> sendMessage({
    required String content,
    String messageType = 'text',
    String? replyTo,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileMimeType,
  }) async {
    // Build optimistic message so it appears immediately
    final tempId = 'temp_${_uuid.v4()}';
    final userId = await SecureStorage.getUserId();
    final optimistic = Message(
      id: tempId,
      conversationId: conversationId,
      sender: userId != null ? User(id: userId, email: '', displayName: 'You') : null,
      content: content,
      messageType: messageType,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      fileMimeType: fileMimeType,
      replyTo: replyTo,
      createdAt: DateTime.now(),
    );
    _addMessage(optimistic);

    final wsClient = _ref.read(webSocketClientProvider);

    if (wsClient.state == WsConnectionState.connected) {
      wsClient.sendMessage(
        conversationId: conversationId,
        content: content,
        messageType: messageType,
        replyTo: replyTo,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
        fileMimeType: fileMimeType,
      );
    } else {
      // REST fallback
      try {
        final repo = _ref.read(messageRepositoryProvider);
        final message = await repo.sendMessage(
          conversationId,
          content: content,
          messageType: messageType,
          replyTo: replyTo,
          fileUrl: fileUrl,
          fileName: fileName,
          fileSize: fileSize,
          fileMimeType: fileMimeType,
        );
        // Replace optimistic message with the real one
        _replaceOptimistic(tempId, message);
      } catch (e) {
        // Mark the optimistic message as failed so user can retry
        _markFailed(tempId);
      }
    }

    // Stop typing indicator
    _sendTyping(false);
  }

  /// Upload a file and send it as a message.
  Future<void> sendFile(String filePath) async {
    try {
      final repo = _ref.read(messageRepositoryProvider);
      final result = await repo.uploadFile(filePath);

      // Determine message type from MIME
      String msgType = 'file';
      if (result.mimeType.startsWith('image/')) {
        msgType = 'image';
      } else if (result.mimeType.startsWith('audio/')) {
        msgType = 'voice';
      } else if (result.mimeType.startsWith('video/')) {
        msgType = 'video';
      }

      await sendMessage(
        content: result.fileName,
        messageType: msgType,
        fileUrl: result.fileUrl,
        fileName: result.fileName,
        fileSize: result.fileSize,
        fileMimeType: result.mimeType,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to upload file');
    }
  }

  /// Notify typing status.
  void onTypingChanged(bool isTyping) {
    if (isTyping && !_isTypingSent) {
      _sendTyping(true);
      _isTypingSent = true;
      // Auto-stop typing after 3 seconds of inactivity
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _sendTyping(false);
        _isTypingSent = false;
      });
    } else if (isTyping) {
      // Reset the timer
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _sendTyping(false);
        _isTypingSent = false;
      });
    } else {
      _sendTyping(false);
      _isTypingSent = false;
      _typingTimer?.cancel();
    }
  }

  /// Mark a message as read.
  Future<void> markAsRead(String messageId) async {
    try {
      final wsClient = _ref.read(webSocketClientProvider);
      wsClient.sendReadReceipt(
        conversationId: conversationId,
        messageId: messageId,
      );
    } catch (_) {}
  }

  /// Mark ALL unread received messages as read (called when opening chat).
  Future<void> markAllAsRead(String currentUserId) async {
    // Update UI immediately
    final updated = state.messages.map((m) {
      if (!m.isRead && m.sender?.id != currentUserId) {
        return m.copyWith(isRead: true);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);

    // Single REST call to mark all messages as read on the server
    try {
      final repo = _ref.read(messageRepositoryProvider);
      await repo.markAllAsRead(conversationId);
    } catch (_) {
      // Fallback: send individual read receipts via WebSocket
      final wsClient = _ref.read(webSocketClientProvider);
      if (wsClient.state == WsConnectionState.connected) {
        final unread = state.messages
            .where(
              (m) =>
                  !m.isRead &&
                  m.sender?.id != currentUserId &&
                  !m.id.startsWith('temp_'),
            )
            .toList();
        for (final msg in unread) {
          try {
            wsClient.sendReadReceipt(
              conversationId: conversationId,
              messageId: msg.id,
            );
          } catch (_) {}
        }
      }
    }
  }

  /// Returns the index of the first unread message (in the reversed list used by ListView).
  /// Messages are stored newest-first, so we search from the end to find the oldest unread.
  int? firstUnreadIndex(String currentUserId) {
    for (int i = state.messages.length - 1; i >= 0; i--) {
      final m = state.messages[i];
      if (!m.isRead && m.sender?.id != currentUserId) {
        return i;
      }
    }
    return null;
  }

  /// Toggle a reaction on a message (optimistic + REST).
  Future<void> toggleReaction(String messageId, String emoji) async {
    final userId = await SecureStorage.getUserId();
    if (userId == null) return;

    // Save old reactions for potential revert
    final oldMessages = List<Message>.from(state.messages);

    // Optimistic update
    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      final existing = m.reactions.where((r) => r.userId == userId).firstOrNull;
      List<MessageReaction> newReactions;
      if (existing != null && existing.emoji == emoji) {
        // Toggle off
        newReactions = m.reactions.where((r) => r.userId != userId).toList();
      } else {
        // Add or change
        newReactions = [
          ...m.reactions.where((r) => r.userId != userId),
          MessageReaction(emoji: emoji, userId: userId, userDisplayName: 'You'),
        ];
      }
      return m.copyWith(reactions: newReactions);
    }).toList();
    state = state.copyWith(messages: updated);

    // REST call
    try {
      final repo = _ref.read(messageRepositoryProvider);
      await repo.toggleReaction(messageId, emoji);
    } catch (_) {
      // Revert optimistic update on failure
      if (mounted) state = state.copyWith(messages: oldMessages);
    }
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    try {
      final repo = _ref.read(messageRepositoryProvider);
      await repo.deleteMessage(messageId);
      final updated = state.messages
          .where((m) => m.id != messageId)
          .toList();
      state = state.copyWith(messages: updated);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete message');
    }
  }

  void _sendTyping(bool isTyping) {
    final wsClient = _ref.read(webSocketClientProvider);
    wsClient.sendTyping(
      conversationId: conversationId,
      isTyping: isTyping,
    );
  }

  void _subscribeToWebSocket() {
    final wsClient = _ref.read(webSocketClientProvider);
    _wsSubscription = wsClient.messageStream.listen((message) {
      final type = message['type'] as String?;
      switch (type) {
        case 'chat.message':
          _handleIncomingMessage(message['message']);
          break;
        case 'chat.typing':
          _handleTyping(message);
          break;
        case 'chat.read':
          _handleReadReceipt(message);
          break;
        case 'chat.deleted':
          _handleDeletion(message);
          break;
        case 'chat.reaction':
          _handleReaction(message);
          break;
        case 'chat.timer_update':
          _handleTimerUpdate(message);
          break;
      }
    });
  }

  void _handleIncomingMessage(Map<String, dynamic>? messageData) {
    if (messageData == null) return;
    final msg = Message.fromJson(messageData);
    if (msg.conversationId != conversationId) return;

    // Avoid duplicates (by real server ID)
    if (state.messages.any((m) => m.id == msg.id)) return;

    // Replace the oldest temp message from this sender (optimistic), or just add
    final tempIndex = state.messages.indexWhere((m) => m.id.startsWith('temp_'));
    if (tempIndex != -1) {
      final updated = List<Message>.from(state.messages);
      updated[tempIndex] = msg;
      state = state.copyWith(messages: updated);
    } else {
      _addMessage(msg);
    }
  }

  void _addMessage(Message message) {
    state = state.copyWith(
      messages: [message, ...state.messages],
    );
  }

  void _replaceOptimistic(String tempId, Message real) {
    final updated = state.messages.map((m) => m.id == tempId ? real : m).toList();
    state = state.copyWith(messages: updated);
  }

  void _removeMessage(String messageId) {
    final updated = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updated);
  }

  void _markFailed(String messageId) {
    final updated = state.messages.map((m) {
      if (m.id == messageId) return m.copyWith(isFailed: true);
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  /// Retry sending a failed message.
  Future<void> retryMessage(String messageId) async {
    final failedMsg = state.messages.where((m) => m.id == messageId).firstOrNull;
    if (failedMsg == null) return;

    // Remove the failed message
    _removeMessage(messageId);

    // Re-send it
    await sendMessage(
      content: failedMsg.content ?? '',
      messageType: failedMsg.messageType,
      replyTo: failedMsg.replyTo,
      fileUrl: failedMsg.fileUrl,
      fileName: failedMsg.fileName,
      fileSize: failedMsg.fileSize,
      fileMimeType: failedMsg.fileMimeType,
    );
  }

  void _handleTyping(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    if (convId != conversationId) return;

    final userId = data['user_id'] as String? ?? '';
    final isTyping = data['is_typing'] as bool? ?? false;
    final displayName = data['display_name'] as String? ?? '';

    final key = displayName.isNotEmpty ? displayName : userId;
    final updatedTyping = Map<String, bool>.from(state.typingUsers);
    if (isTyping) {
      updatedTyping[key] = true;
    } else {
      updatedTyping.remove(key);
    }
    state = state.copyWith(typingUsers: updatedTyping);

    // Update the conversation-list typing indicator
    try {
      final typingMap = Map<String, List<String>>.from(
        _ref.read(typingConversationsProvider),
      );
      if (updatedTyping.isEmpty) {
        typingMap.remove(conversationId);
      } else {
        typingMap[conversationId] = updatedTyping.keys.toList();
      }
      _ref.read(typingConversationsProvider.notifier).state = typingMap;
    } catch (_) {}
  }

  void _handleReadReceipt(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    if (convId != conversationId) return;

    final messageId = data['message_id'] as String?;
    if (messageId == null) return;

    final updated = state.messages.map((m) {
      if (m.id == messageId) return m.copyWith(isRead: true);
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  void _handleTimerUpdate(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    if (convId != conversationId) return;

    final newTimer = data['auto_delete_timer'] as int?;
    state = state.copyWith(
      autoDeleteTimer: newTimer,
      timerUpdated: true,
      clearTimer: newTimer == null,
    );
  }

  void _handleReaction(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    if (convId != conversationId) return;

    final messageId = data['message_id'] as String?;
    final userId = data['user_id'] as String?;
    final displayName = data['user_display_name'] as String? ?? '';
    final emoji = data['emoji'] as String? ?? '';
    final action = data['action'] as String?;
    if (messageId == null || userId == null) return;

    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      List<MessageReaction> newReactions;
      if (action == 'removed') {
        newReactions = m.reactions.where((r) => r.userId != userId).toList();
      } else {
        // added or changed — replace any existing reaction from this user
        newReactions = [
          ...m.reactions.where((r) => r.userId != userId),
          MessageReaction(emoji: emoji, userId: userId, userDisplayName: displayName),
        ];
      }
      return m.copyWith(reactions: newReactions);
    }).toList();
    state = state.copyWith(messages: updated);
  }

  void _handleDeletion(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    if (convId != conversationId) return;

    final deletedIds = (data['message_ids'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        {};

    final updated = state.messages
        .where((m) => !deletedIds.contains(m.id))
        .toList();
    state = state.copyWith(messages: updated);
  }
}
