import 'package:dio/dio.dart';

/// API service for conversation endpoints.
class ConversationApi {
  final Dio _dio;

  ConversationApi(this._dio);

  /// Fetch paginated list of user's conversations.
  Future<Map<String, dynamic>> getConversations({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _dio.get('/conversations/', queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Get conversation details by ID.
  Future<Map<String, dynamic>> getConversation(String id) async {
    final response = await _dio.get('/conversations/$id/');
    return response.data as Map<String, dynamic>;
  }

  /// Create a direct conversation with another user.
  Future<Map<String, dynamic>> createDirectConversation(String userId) async {
    final response = await _dio.post('/conversations/', data: {
      'type': 'direct',
      'user_id': userId,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Create a group conversation.
  Future<Map<String, dynamic>> createGroupConversation({
    required String name,
    required List<String> memberIds,
  }) async {
    final response = await _dio.post('/conversations/', data: {
      'type': 'group',
      'name': name,
      'member_ids': memberIds,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Update conversation settings (name, avatar, auto_delete_timer).
  Future<Map<String, dynamic>> updateConversation(
    String id, {
    String? name,
    String? avatarUrl,
    int? autoDeleteTimer,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    data['auto_delete_timer'] = autoDeleteTimer;

    final response = await _dio.patch('/conversations/$id/', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Leave or delete a conversation.
  Future<void> deleteConversation(String id) async {
    await _dio.delete('/conversations/$id/');
  }

  /// Add members to a group conversation.
  Future<void> addMembers(String conversationId, List<String> userIds) async {
    await _dio.post('/conversations/$conversationId/members/', data: {
      'user_ids': userIds,
    });
  }

  /// Remove a member from a group conversation.
  Future<void> removeMember(String conversationId, String userId) async {
    await _dio.delete('/conversations/$conversationId/members/$userId/');
  }

  /// Search users by email or display name.
  Future<List<dynamic>> searchUsers(String query) async {
    final response = await _dio.get('/users/search/', queryParameters: {
      'q': query,
    });
    // The response is paginated; extract results
    if (response.data is Map) {
      return (response.data['results'] as List?) ?? [];
    }
    return response.data as List;
  }
}
