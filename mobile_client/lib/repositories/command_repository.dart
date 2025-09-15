import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/constants.dart';
import '../services/connection_status.dart';

class CommandRepository {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;

  final StreamController<String> _messageController =
      StreamController.broadcast();
  final StreamController<ConnectionStatus> _statusController =
      StreamController.broadcast();

  Stream<String> get messages => _messageController.stream;
  Stream<ConnectionStatus> get status => _statusController.stream;

  bool _isOnline = false;
  Timer? _reconnectTimer;

  void connect(String jwt, String deviceId) {
    _reconnectTimer?.cancel();
    _disconnect(notify: false);

    _isOnline = false;
    _statusController.add(ConnectionStatus.connecting);
    debugPrint("[CommandRepository] Connecting...");

    _attemptConnection(jwt, deviceId);
  }

  // HATA DÜZELTME: Kullanılmayan 'attempt' parametresi kaldırıldı.
  void _attemptConnection(String jwt, String deviceId) {
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
            debugPrint("[CommandRepository] Connection established.");
          }
          _messageController.add(message);
        },
        onDone: () {
          debugPrint("[CommandRepository] WebSocket onDone. Connection lost.");
          _handleDisconnect(
            shouldReconnect: true,
            jwt: jwt,
            deviceId: deviceId,
          );
        },
        onError: (error) {
          debugPrint(
            "[CommandRepository] WebSocket onError: $error. Connection lost.",
          );
          _handleDisconnect(
            shouldReconnect: true,
            jwt: jwt,
            deviceId: deviceId,
          );
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint("[CommandRepository] WebSocket connect catch: $e");
      _handleDisconnect(shouldReconnect: true, jwt: jwt, deviceId: deviceId);
    }
  }

  void _handleDisconnect({
    bool shouldReconnect = false,
    String? jwt,
    String? deviceId,
  }) {
    if (_statusController.isClosed) return;

    if (_isOnline || _connectionStatus != ConnectionStatus.offline) {
      _isOnline = false;
      _statusController.add(ConnectionStatus.offline);
    }

    _channelSubscription?.cancel();
    _channel = null;

    if (shouldReconnect && jwt != null && deviceId != null) {
      _scheduleReconnect(jwt, deviceId);
    }
  }

  void _scheduleReconnect(String jwt, String deviceId) {
    _reconnectTimer?.cancel();
    final reconnectDelay = Duration(seconds: 5); // Sabit 5 saniye gecikme
    debugPrint(
      "[CommandRepository] Scheduling reconnect in ${reconnectDelay.inSeconds} seconds.",
    );
    _reconnectTimer = Timer(reconnectDelay, () {
      debugPrint("[CommandRepository] Reconnecting now...");
      connect(jwt, deviceId);
    });
  }

  void send(String jsonData) {
    if (_channel != null && _isOnline) {
      _channel!.sink.add(jsonData);
    } else {
      debugPrint(
        "[CommandRepository] Cannot send data: Channel not connected.",
      );
    }
  }

  void _disconnect({bool notify = true}) {
    _reconnectTimer?.cancel();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    if (notify) {
      _handleDisconnect();
    }
  }

  void dispose() {
    _disconnect();
    _messageController.close();
    _statusController.close();
  }

  ConnectionStatus get _connectionStatus => _statusController.hasListener
      ? (_isOnline ? ConnectionStatus.online : ConnectionStatus.offline)
      : ConnectionStatus.offline;
}
