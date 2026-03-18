import '../../../models/conversation.dart';
import '../../../models/user.dart';
import 'conversation_api.dart';

/// Repository for conversation data operations.
class ConversationRepository {
  final ConversationApi _api;

  ConversationRepository(this._api);

  /// Fetch user's conversations list.
  Future<List<Conversation>> getConversations({
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _api.getConversations(limit: limit, offset: offset);
    final results = (data['results'] as List?) ?? [];
    return results.map((json) => Conversation.fromJson(json)).toList();
  }

  /// Get a single conversation's details.
  Future<Conversation> getConversation(String id) async {
    final data = await _api.getConversation(id);
    return Conversation.fromJson(data);
  }

  /// Create a direct (1-on-1) conversation.
  Future<Conversation> createDirectConversation(String userId) async {
    final data = await _api.createDirectConversation(userId);
    return Conversation.fromJson(data);
  }

  /// Create a group conversation.
  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> memberIds,
  }) async {
    final data = await _api.createGroupConversation(
      name: name,
      memberIds: memberIds,
    );
    return Conversation.fromJson(data);
  }

  /// Update conversation settings.
  Future<void> updateConversation(
    String id, {
    String? name,
    int? autoDeleteTimer,
  }) async {
    await _api.updateConversation(
      id,
      name: name,
      autoDeleteTimer: autoDeleteTimer,
    );
  }

  /// Leave/delete a conversation.
  Future<void> deleteConversation(String id) async {
    await _api.deleteConversation(id);
  }

  /// Search for users.
  Future<List<User>> searchUsers(String query) async {
    final results = await _api.searchUsers(query);
    return results.map((json) => User.fromJson(json)).toList();
  }
}
