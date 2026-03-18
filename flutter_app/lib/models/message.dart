import 'package:equatable/equatable.dart';
import 'user.dart';

/// Chat message model with support for text, image, voice, and file types.
class Message extends Equatable {
  final String id;
  final String conversationId;
  final User? sender;
  final String? content;
  final String messageType;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? fileMimeType;
  final String? replyTo;
  final ReplyPreview? replyToPreview;
  final DateTime? expiresAt;
  final bool isDeleted;
  final bool isRead;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.conversationId,
    this.sender,
    this.content,
    this.messageType = 'text',
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.fileMimeType,
    this.replyTo,
    this.replyToPreview,
    this.expiresAt,
    this.isDeleted = false,
    this.isRead = false,
    required this.createdAt,
  });

  /// Whether this message was sent by the given user ID.
  bool isSentBy(String userId) => sender?.id == userId;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
      content: json['content'],
      messageType: json['message_type'] ?? 'text',
      fileUrl: json['file_url'],
      fileName: json['file_name'],
      fileSize: json['file_size'],
      fileMimeType: json['file_mime_type'],
      replyTo: json['reply_to'],
      replyToPreview: json['reply_to_preview'] != null
          ? ReplyPreview.fromJson(json['reply_to_preview'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      isDeleted: json['is_deleted'] ?? false,
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Message copyWith({bool? isRead}) {
    return Message(
      id: id,
      conversationId: conversationId,
      sender: sender,
      content: content,
      messageType: messageType,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      fileMimeType: fileMimeType,
      replyTo: replyTo,
      replyToPreview: replyToPreview,
      expiresAt: expiresAt,
      isDeleted: isDeleted,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, conversationId, content, isDeleted, isRead];
}

/// Preview of a replied-to message.
class ReplyPreview extends Equatable {
  final String id;
  final String? content;
  final String? senderName;
  final String messageType;

  const ReplyPreview({
    required this.id,
    this.content,
    this.senderName,
    this.messageType = 'text',
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json) {
    return ReplyPreview(
      id: json['id'] ?? '',
      content: json['content'],
      senderName: json['sender_name'],
      messageType: json['message_type'] ?? 'text',
    );
  }

  @override
  List<Object?> get props => [id, content, senderName];
}
