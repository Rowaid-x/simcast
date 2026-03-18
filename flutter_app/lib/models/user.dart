import 'package:equatable/equatable.dart';

/// User model representing a Whisper user.
class User extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String bio;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.bio = '',
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? '',
      avatarUrl: json['avatar_url'],
      bio: json['bio'] ?? '',
      isOnline: json['is_online'] ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  User copyWith({
    String? displayName,
    String? avatarUrl,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return User(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, email, displayName, isOnline];
}
