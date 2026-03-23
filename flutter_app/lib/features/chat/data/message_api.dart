import 'package:dio/dio.dart';

/// API service for message endpoints.
class MessageApi {
  final Dio _dio;

  MessageApi(this._dio);

  /// Fetch paginated messages for a conversation.
  Future<Map<String, dynamic>> getMessages(
    String conversationId, {
    String? cursor,
    int pageSize = 30,
  }) async {
    final params = <String, dynamic>{'page_size': pageSize};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _dio.get(
      '/conversations/$conversationId/messages/',
      queryParameters: params,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Send a new message via REST (fallback when WebSocket is unavailable).
  Future<Map<String, dynamic>> sendMessage(
    String conversationId, {
    required String content,
    String messageType = 'text',
    String? replyTo,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileMimeType,
  }) async {
    final data = <String, dynamic>{
      'content': content,
      'message_type': messageType,
    };
    if (replyTo != null) data['reply_to'] = replyTo;
    if (fileUrl != null) data['file_url'] = fileUrl;
    if (fileName != null) data['file_name'] = fileName;
    if (fileSize != null) data['file_size'] = fileSize;
    if (fileMimeType != null) data['file_mime_type'] = fileMimeType;

    final response = await _dio.post(
      '/conversations/$conversationId/messages/',
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    await _dio.delete('/messages/$messageId/');
  }

  /// Mark a message as read.
  Future<void> markAsRead(String messageId) async {
    await _dio.post('/messages/$messageId/read/');
  }

  /// Mark all messages in a conversation as read for the current user.
  Future<void> markAllAsRead(String conversationId) async {
    await _dio.post('/conversations/$conversationId/messages/read-all/');
  }

  /// Upload a file.
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post('/upload/', data: formData);
    return response.data as Map<String, dynamic>;
  }
}
