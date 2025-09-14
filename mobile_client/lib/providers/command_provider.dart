import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../models/messages/app_message.dart';
import '../models/messages/generic_message.dart';
import '../models/messages/user_command_message.dart';
import '../services/connection_status.dart';
import '../services/websocket_service.dart';
import 'auth_provider.dart';
import 'device_provider.dart';
import '../services/device_identity_service.dart';

class CommandProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  final DeviceIdentityService _identityService = DeviceIdentityService();
  final AuthProvider authProvider;
  final DeviceProvider deviceProvider;
  final _uuid = const Uuid();

  StreamSubscription? _messageSubscription;
  StreamSubscription? _statusSubscription;
  VoidCallback? onAuthError;

  bool _isConfirmationPending = false;
  String? _pendingIntent;
  String? _pendingExplanation;
  bool get isConfirmationPending => _isConfirmationPending;
  String? get pendingIntent => _pendingIntent;
  String? get pendingExplanation => _pendingExplanation;

  bool _isAgentOnline = false;
  bool get isAgentOnline => _isAgentOnline;

  ConnectionStatus _connectionStatus = ConnectionStatus.offline;
  final List<AppMessage> _messages = [];

  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == ConnectionStatus.online;
  List<AppMessage> get messages => _messages;

  CommandProvider({required this.authProvider, required this.deviceProvider}) {
    authProvider.addListener(_onAuthChanged);
    _statusSubscription = _webSocketService.status.listen(_onStatusChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    if (authProvider.isAuthenticated) {
      Future.microtask(() {
        deviceProvider.fetchDevices();
      });
      _connectAndListen();
    } else {
      _isAgentOnline = false;
      _disconnect();
    }
  }

  void _onStatusChanged(ConnectionStatus status) {
    if (_connectionStatus == status) return;
    _connectionStatus = status;
    if (status == ConnectionStatus.offline ||
        status == ConnectionStatus.connecting) {
      _isAgentOnline = false;
    }
    notifyListeners();
  }

  void _connectAndListen() async {
    if (authProvider.token == null ||
        _connectionStatus == ConnectionStatus.connecting)
      return;
    final deviceId = await _identityService.getOrCreateDeviceId();
    _webSocketService.connect(authProvider.token!, deviceId);
    _messageSubscription?.cancel();
    _messageSubscription = _webSocketService.messages.listen(
      (messageString) {
        try {
          final data = json.decode(messageString);

          final receivedCommandId = data['commandId'] as String?;
          if (receivedCommandId != null) {
            debugPrint(
              '✅ [CommandProvider] Received message with commandId: $receivedCommandId',
            );
          } else {
            debugPrint(
              'ℹ️ [CommandProvider] Received message without commandId: ${data['type']}',
            );
          }

          final msgType = data['type'] as String?;

          if (msgType == 'agent_status_changed') {
            final newStatusStr = data['status'] as String?;
            final newStatus = newStatusStr == 'ONLINE';
            if (_isAgentOnline != newStatus) {
              _isAgentOnline = newStatus;
              debugPrint('Agent status changed via PUSH to: $_isAgentOnline');
              notifyListeners();
            }
            return;
          }

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
        if (error.toString().contains('401')) onAuthError?.call();
      },
    );
  }

  void _disconnect() {
    _webSocketService.disconnect();
    _messageSubscription?.cancel();
  }

  void sendCommand(String prompt) {
    if (!isAgentOnline) {
      _messages.add(GenericMessage("Error: No online agent to send command."));
      notifyListeners();
      return;
    }

    final commandId = _uuid.v4();
    debugPrint(
      '🚀 [CommandProvider] Sending command with commandId: $commandId',
    );
    final commandData = {
      'type': 'command',
      'prompt': prompt,
      'commandId': commandId,
    };
    final commandJson = json.encode(commandData);

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

  void clearConfirmation() {
    _isConfirmationPending = false;
    _pendingIntent = null;
    _pendingExplanation = null;
    notifyListeners();
  }

  @override
  void dispose() {
    authProvider.removeListener(_onAuthChanged);
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }
}
