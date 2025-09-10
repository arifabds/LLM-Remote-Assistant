import 'package:flutter/material.dart';
import 'dart:async';
import '../services/websocket_service.dart';
import 'auth_provider.dart';
import 'dart:convert';

class CommandProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  late AuthProvider _authProvider;
  StreamSubscription? _messageSubscription;
  VoidCallback? onAuthError;

  bool _isConfirmationPending = false;
  String? _pendingIntent;
  String? _pendingExplanation;

  bool get isConfirmationPending => _isConfirmationPending;
  String? get pendingIntent => _pendingIntent;
  String? get pendingExplanation => _pendingExplanation;

  bool _isConnected = false;
  final List<String> _consoleMessages = [];

  bool get isConnected => _isConnected;
  List<String> get consoleMessages => _consoleMessages;

  void update(AuthProvider authProvider, {VoidCallback? onAuthErrorCallback}) {
    _authProvider = authProvider;
    onAuthError = onAuthErrorCallback;

    if (_authProvider.isAuthenticated && !_isConnected) {
      _connect();
    } else if (!_authProvider.isAuthenticated && _isConnected) {
      _disconnect();
    }
  }

  void _connect() {
    if (_authProvider.token == null || _authProvider.token!.isEmpty) {
      _consoleMessages.add('Error: Could not connect. Auth token is missing.');
      notifyListeners();
      return;
    }

    _webSocketService.connect(_authProvider.token!);
    _isConnected = true;
    _consoleMessages.add('Connecting to server...');

    _messageSubscription = _webSocketService.messages.listen(
      (message) {
        _consoleMessages.add('Server: $message');

        try {
          final Map<String, dynamic> data = json.decode(message);
          final String? msgType = data['type'] as String?;

          if (msgType == 'confirmation_required') {
            _isConfirmationPending = true;
            _pendingIntent = data['intent'] as String?;
            _pendingExplanation = data['explanation'] as String?;
          }
        } catch (e) {
          // empty block for now
        }

        notifyListeners();
      },
      onError: (error) {
        if (error.toString().contains('401')) {
          onAuthError?.call();
        }
        _consoleMessages.add('WebSocket Error: ${error.toString()}');
        notifyListeners();
      },
      onDone: () {
        _disconnect();
      },
    );

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

  void clearConfirmation() {
    _isConfirmationPending = false;
    _pendingIntent = null;
    _pendingExplanation = null;
    notifyListeners();
  }
}
