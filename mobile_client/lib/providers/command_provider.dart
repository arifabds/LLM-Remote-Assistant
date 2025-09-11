import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../models/message_model.dart';
import '../services/websocket_service.dart';
import 'auth_provider.dart';

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
  final List<AppMessage> _messages = [];

  bool get isConnected => _isConnected;
  List<AppMessage> get messages => _messages;

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
      _messages.add(
        GenericMessage('Error: Could not connect. Auth token is missing.'),
      );
      notifyListeners();
      return;
    }

    _webSocketService.connect(_authProvider.token!);
    _isConnected = true;
    _messages.add(GenericMessage('Connecting to server...'));

    _messageSubscription = _webSocketService.messages.listen(
      (messageString) {
        try {
          final Map<String, dynamic> data = json.decode(messageString);
          final String? msgType = data['type'] as String?;

          if (msgType == 'confirmation_required') {
            _isConfirmationPending = true;
            _pendingIntent = data['intent'] as String?;
            _pendingExplanation = data['explanation'] as String?;
          } else {
            _messages.add(AppMessage.fromJson(messageString, data));
          }
        } catch (e) {
          _messages.add(GenericMessage(messageString));
        }

        notifyListeners();
      },
      onError: (error) {
        if (error.toString().contains('401')) {
          onAuthError?.call();
        }
        _messages.add(GenericMessage('WebSocket Error: ${error.toString()}'));
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
    _messages.add(GenericMessage('Disconnected from server.'));
    notifyListeners();
  }

  void sendCommand(String prompt) {
    final commandJson = '{"type": "command", "prompt": "$prompt"}';
    _messages.add(UserCommandMessage(prompt));
    _webSocketService.sendCommand(commandJson);
    notifyListeners();
  }

  void sendConfirmationResponse(bool approved) {
    if (!_isConfirmationPending || _pendingIntent == null) return;

    final responseJson = json.encode({
      "type": "confirmation_response",
      "approved": approved,
      "intent": _pendingIntent,
    });

    _messages.add(
      GenericMessage(
        'You: Responded with "${approved ? 'APPROVE' : 'CANCEL'}" for intent: "$_pendingIntent"',
      ),
    );
    _webSocketService.sendCommand(responseJson);

    clearConfirmation();
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
