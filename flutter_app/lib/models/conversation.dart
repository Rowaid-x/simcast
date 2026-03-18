import 'package:equatable/equatable.dart';
import 'message.dart';
import 'user.dart';

/// Conversation model for direct and group chats.
class Conversation extends Equatable {
  final String id;
  final String type;
  final String? name;
  final String? avatarUrl;
  final int? autoDeleteTimer;
  final Message? lastMessage;
  final int unreadCount;
  final User? otherUser;
  final int memberCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    this.autoDeleteTimer,
    this.lastMessage,
    this.unreadCount = 0,
    this.otherUser,
    this.memberCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display name: for direct chats use other user's name, for groups use the group name.
  String get displayName {
    if (type == 'direct' && otherUser != null) {
      return otherUser!.displayName;
    }
    return name ?? 'Unnamed Group';
  }

  /// Display avatar URL.
  String? get displayAvatar {
    if (type == 'direct' && otherUser != null) {
      return otherUser!.avatarUrl;
    }
    return avatarUrl;
  }

  /// Whether the other user is online (direct chats only).
  bool get isOtherUserOnline {
    if (type == 'direct' && otherUser != null) {
      return otherUser!.isOnline;
    }
    return false;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      type: json['type'] ?? 'direct',
      name: json['name'],
      avatarUrl: json['avatar_url'],
      autoDeleteTimer: json['auto_delete_timer'],
      lastMessage: json['last_message'] != null
          ? Message.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      otherUser: json['other_user'] != null
          ? User.fromJson(json['other_user'])
          : null,
      memberCount: json['member_count'] ?? 0,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Conversation copyWith({
    int? unreadCount,
    Message? lastMessage,
    int? autoDeleteTimer,
    User? otherUser,
  }) {
    return Conversation(
      id: id,
      type: type,
      name: name,
      avatarUrl: avatarUrl,
      autoDeleteTimer: autoDeleteTimer ?? this.autoDeleteTimer,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      otherUser: otherUser ?? this.otherUser,
      memberCount: memberCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, type, name, unreadCount];
}
