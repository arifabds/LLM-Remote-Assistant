import 'package:flutter/material.dart';
import 'dart:async';
import '../services/websocket_service.dart';
import 'auth_provider.dart';

class CommandProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  late AuthProvider _authProvider;
  StreamSubscription? _messageSubscription;

  bool _isConnected = false;
  final List<String> _consoleMessages = [];

  bool get isConnected => _isConnected;
  List<String> get consoleMessages => _consoleMessages;

  void update(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (_authProvider.isAuthenticated && !_isConnected) {
      _connect();
    } else if (!_authProvider.isAuthenticated && _isConnected) {
      _disconnect();
    }
  }

  void _connect() {
    if (_authProvider.token == null) return;

    _webSocketService.connect(_authProvider.token!);
    _isConnected = true;
    _consoleMessages.add('Connecting to server...');

    _messageSubscription = _webSocketService.messages.listen((message) {
      _consoleMessages.add('Server: $message');
      notifyListeners();
    });

    notifyListeners();
  }

  void _disconnect() {
    _webSocketService.disconnect();
    _messageSubscription?.cancel();
    _isConnected = false;
    _consoleMessages.add('Disconnected from server.');
    notifyListeners();
  }

  void sendCommand(String prompt) {
    final commandJson = '{"type": "command", "prompt": "$prompt"}';
    _consoleMessages.add('You: $prompt');
    _webSocketService.sendCommand(commandJson);
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _webSocketService.disconnect();
    super.dispose();
  }
}
