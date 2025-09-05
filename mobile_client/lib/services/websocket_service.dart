import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/constants.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<String> _messageController =
      StreamController.broadcast();

  Stream<String> get messages => _messageController.stream;

  void connect(String jwt) {
    if (_channel != null || jwt.isEmpty) return;

    final uri = Uri.parse('$webSocketUrl?clientType=mobile');

    _channel = IOWebSocketChannel.connect(
      uri,
      headers: {'Authorization': 'Bearer $jwt'},
    );

    _channel!.stream.listen(
      (message) {
        _messageController.add(message);
      },
      onDone: () {
        disconnect();
      },
      onError: (error) {
        _messageController.add('Error: $error');
        disconnect();
      },
    );
  }

  void sendCommand(String commandJson) {
    if (_channel != null) {
      _channel!.sink.add(commandJson);
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
  }
}
