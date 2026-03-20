import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../models/message.dart';
import '../../../models/user.dart';
import '../data/message_api.dart';
import '../data/message_repository.dart';

const _uuid = Uuid();

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

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.nextCursor,
    this.error,
    this.typingUsers = const {},
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? hasMore,
    String? nextCursor,
    String? error,
    Map<String, bool>? typingUsers,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: error,
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }
}

/// Provider family for per-conversation chat state.
final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, conversationId) => ChatNotifier(ref, conversationId),
);

/// Notifier managing chat messages for a specific conversation.
class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  final String conversationId;
  StreamSubscription? _wsSubscription;
  Timer? _typingTimer;
  bool _isTypingSent = false;

  ChatNotifier(this._ref, this.conversationId) : super(const ChatState()) {
    _loadInitialMessages();
    _subscribeToWebSocket();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  /// Load the first page of messages.
  Future<void> _loadInitialMessages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(messageRepositoryProvider);
      final page = await repo.getMessages(conversationId);
      state = state.copyWith(
        messages: page.messages,
        isLoading: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load messages',
      );
    }
  }

  /// Load more (older) messages for infinite scroll.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(messageRepositoryProvider);
      final page = await repo.getMessages(
        conversationId,
        cursor: state.nextCursor,
      );
      state = state.copyWith(
        messages: [...state.messages, ...page.messages],
        isLoading: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
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
        // Remove the optimistic message on failure
        _removeMessage(tempId);
        state = state.copyWith(error: 'Failed to send message');
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

  void _handleTyping(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    if (convId != conversationId) return;

    final userId = data['user_id'] as String? ?? '';
    final isTyping = data['is_typing'] as bool? ?? false;
    final displayName = data['display_name'] as String? ?? '';

    final updatedTyping = Map<String, bool>.from(state.typingUsers);
    if (isTyping) {
      updatedTyping[displayName.isNotEmpty ? displayName : userId] = true;
    } else {
      updatedTyping.remove(displayName.isNotEmpty ? displayName : userId);
    }
    state = state.copyWith(typingUsers: updatedTyping);
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
