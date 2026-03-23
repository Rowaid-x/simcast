import '../../../models/message.dart';
import 'message_api.dart';

/// Repository for message data operations.
class MessageRepository {
  final MessageApi _api;

  MessageRepository(this._api);

  /// Fetch messages for a conversation with cursor-based pagination.
  Future<MessagePage> getMessages(
    String conversationId, {
    String? cursor,
    int pageSize = 30,
  }) async {
    final data = await _api.getMessages(
      conversationId,
      cursor: cursor,
      pageSize: pageSize,
    );
    final results = (data['results'] as List?) ?? [];
    final messages = results
        .map((json) => Message.fromJson(json as Map<String, dynamic>))
        .toList();
    return MessagePage(
      messages: messages,
      nextCursor: data['next'] as String?,
      previousCursor: data['previous'] as String?,
    );
  }

  /// Send a message via REST API.
  Future<Message> sendMessage(
    String conversationId, {
    required String content,
    String messageType = 'text',
    String? replyTo,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileMimeType,
  }) async {
    final data = await _api.sendMessage(
      conversationId,
      content: content,
      messageType: messageType,
      replyTo: replyTo,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      fileMimeType: fileMimeType,
    );
    return Message.fromJson(data);
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    await _api.deleteMessage(messageId);
  }

  /// Mark a message as read.
  Future<void> markAsRead(String messageId) async {
    await _api.markAsRead(messageId);
  }

  /// Mark all messages in a conversation as read.
  Future<void> markAllAsRead(String conversationId) async {
    await _api.markAllAsRead(conversationId);
  }

  /// Get who read a message (for group chats).
  Future<List<ReadByEntry>> getReadBy(String messageId) async {
    final data = await _api.getReadBy(messageId);
    return data
        .map((json) => ReadByEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Toggle a reaction on a message.
  Future<void> toggleReaction(String messageId, String emoji) async {
    await _api.toggleReaction(messageId, emoji);
  }

  /// Upload a file and return metadata.
  Future<FileUploadResult> uploadFile(String filePath) async {
    final data = await _api.uploadFile(filePath);
    return FileUploadResult(
      fileUrl: data['file_url'] as String,
      fileName: data['file_name'] as String,
      fileSize: data['file_size'] as int,
      mimeType: data['mime_type'] as String,
    );
  }
}

/// Represents a page of messages with pagination cursors.
class MessagePage {
  final List<Message> messages;
  final String? nextCursor;
  final String? previousCursor;

  MessagePage({
    required this.messages,
    this.nextCursor,
    this.previousCursor,
  });

  bool get hasMore => nextCursor != null;
}

/// Result of a file upload.
class FileUploadResult {
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String mimeType;

  FileUploadResult({
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
  });
}

/// A single read receipt entry showing who read a message and when.
class ReadByEntry {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final DateTime readAt;

  ReadByEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.readAt,
  });

  factory ReadByEntry.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return ReadByEntry(
      userId: user['id'] as String,
      displayName: user['display_name'] as String? ?? 'Unknown',
      avatarUrl: user['avatar_url'] as String?,
      readAt: DateTime.parse(json['read_at'] as String),
    );
  }
}
