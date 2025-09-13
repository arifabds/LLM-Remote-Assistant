import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/constants.dart';
import 'connection_status.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;

  final StreamController<String> _messageController =
      StreamController.broadcast();
  final StreamController<ConnectionStatus> _statusController =
      StreamController.broadcast();

  Stream<String> get messages => _messageController.stream;
  Stream<ConnectionStatus> get status => _statusController.stream;

  bool _isOnline = false;

  void connect(String jwt, String deviceId) {
    disconnect();
    _isOnline = false;
    _statusController.add(ConnectionStatus.connecting);

    final uri = Uri.parse('$webSocketUrl?clientType=mobile&deviceId=$deviceId');
    try {
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {'Authorization': 'Bearer $jwt'},
      );

      _channelSubscription = _channel!.stream.listen(
        (message) {
          if (!_isOnline) {
            _isOnline = true;
            _statusController.add(ConnectionStatus.online);
          }
          _messageController.add(message);
        },
        onDone: () {
          debugPrint("WebSocket onDone triggered.");
          _handleDisconnect();
        },
        onError: (error) {
          debugPrint("WebSocket onError triggered: $error");
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint("WebSocket connect catch triggered: $e");
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (_statusController.isClosed) return;
    _isOnline = false;
    _statusController.add(ConnectionStatus.offline);
    _channelSubscription?.cancel();
    _channel = null;
  }

  void sendCommand(String commandJson) {
    if (_channel != null) {
      _channel!.sink.add(commandJson);
    }
  }

  void disconnect() {
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
  }
}
