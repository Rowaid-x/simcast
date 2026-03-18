import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/constants.dart';
import '../storage/secure_storage.dart';

/// WebSocket connection states.
enum WsConnectionState { disconnected, connecting, connected, reconnecting }

/// WebSocket client with automatic reconnection using exponential backoff.
class WebSocketClient {
  WebSocketChannel? _channel;
  WsConnectionState _state = WsConnectionState.disconnected;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<WsConnectionState>.broadcast();

  /// Stream of incoming WebSocket messages.
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Stream of connection state changes.
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  /// Current connection state.
  WsConnectionState get state => _state;

  /// Connect to the WebSocket server with JWT authentication.
  Future<void> connect() async {
    if (_state == WsConnectionState.connecting ||
        _state == WsConnectionState.connected) {
      return;
    }

    _updateState(WsConnectionState.connecting);

    try {
      final token = await SecureStorage.getAccessToken();
      if (token == null) {
        _updateState(WsConnectionState.disconnected);
        return;
      }

      final uri = Uri.parse('${AppConstants.wsUrl}?token=$token');
      _channel = WebSocketChannel.connect(uri);

      await _channel!.ready;
      _updateState(WsConnectionState.connected);
      _reconnectAttempts = 0;

      // Start ping timer to keep connection alive
      _startPingTimer();

      // Listen for messages
      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            _messageController.add(message);
          } catch (_) {}
        },
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );
    } catch (e) {
      _handleDisconnect();
    }
  }

  /// Send a JSON message through the WebSocket.
  void send(Map<String, dynamic> message) {
    if (_state != WsConnectionState.connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (_) {
      _handleDisconnect();
    }
  }

  /// Send a chat message.
  void sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? replyTo,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileMimeType,
  }) {
    send({
      'type': 'chat.message',
      'conversation_id': conversationId,
      'content': content,
      'message_type': messageType,
      'reply_to': replyTo,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'file_mime_type': fileMimeType,
    });
  }

  /// Send a typing indicator.
  void sendTyping({
    required String conversationId,
    required bool isTyping,
  }) {
    send({
      'type': 'chat.typing',
      'conversation_id': conversationId,
      'is_typing': isTyping,
    });
  }

  /// Send a read receipt.
  void sendReadReceipt({
    required String conversationId,
    required String messageId,
  }) {
    send({
      'type': 'chat.read',
      'conversation_id': conversationId,
      'message_id': messageId,
    });
  }

  /// Disconnect from the WebSocket server.
  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _updateState(WsConnectionState.disconnected);
    _reconnectAttempts = 0;
  }

  /// Dispose all resources.
  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _channel = null;

    if (_state == WsConnectionState.disconnected) return;

    _updateState(WsConnectionState.reconnecting);
    _scheduleReconnect();
  }

  /// Exponential backoff with jitter for reconnection.
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _updateState(WsConnectionState.disconnected);
      return;
    }

    final baseDelay = min(30, pow(2, _reconnectAttempts).toInt());
    final jitter = Random().nextDouble() * baseDelay * 0.5;
    final delay = Duration(seconds: baseDelay + jitter.toInt());

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      connect();
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_state == WsConnectionState.connected) {
        send({'type': 'ping'});
      }
    });
  }

  void _updateState(WsConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }
}

/// Global WebSocket client provider.
final webSocketClientProvider = Provider<WebSocketClient>((ref) {
  final client = WebSocketClient();
  ref.onDispose(() => client.dispose());
  return client;
});
