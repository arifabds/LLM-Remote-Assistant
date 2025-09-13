import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../models/message_model.dart';
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

  StreamSubscription? _messageSubscription;
  StreamSubscription? _statusSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  VoidCallback? onAuthError;

  bool _isConfirmationPending = false;
  String? _pendingIntent;
  String? _pendingExplanation;
  bool get isConfirmationPending => _isConfirmationPending;
  String? get pendingIntent => _pendingIntent;
  String? get pendingExplanation => _pendingExplanation;

  bool get isAgentOnline => deviceProvider.hasOnlineAgent;

  ConnectionStatus _connectionStatus = ConnectionStatus.offline;
  final List<AppMessage> _messages = [];

  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == ConnectionStatus.online;
  List<AppMessage> get messages => _messages;

  CommandProvider({required this.authProvider, required this.deviceProvider}) {
    authProvider.addListener(_onAuthChanged);
    deviceProvider.addListener(notifyListeners);
    _statusSubscription = _webSocketService.status.listen(_onStatusChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    if (authProvider.isAuthenticated) {
      _connectAndListen();
    } else {
      _disconnect();
    }
  }

  void _onStatusChanged(ConnectionStatus status) {
    if (_connectionStatus == status) return;
    _connectionStatus = status;
    notifyListeners();

    if (status == ConnectionStatus.offline && authProvider.isAuthenticated) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_connectionStatus != ConnectionStatus.connecting) {
      _reconnectAttempts++;
      final delaySeconds = min(pow(2, _reconnectAttempts), 30).toInt();

      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        if (authProvider.isAuthenticated) {
          _connectAndListen();
        }
      });
    }
  }

  void _connectAndListen() async {
    if (authProvider.token == null) return;
    _reconnectTimer?.cancel();

    final deviceId = await _identityService.getOrCreateDeviceId();
    _webSocketService.connect(authProvider.token!, deviceId);

    _messageSubscription?.cancel();
    _messageSubscription = _webSocketService.messages.listen(
      (messageString) {
        _reconnectAttempts = 0;
        try {
          final data = json.decode(messageString);
          final msgType = data['type'] as String?;

          if (msgType == 'agent_status_changed') {
            debugPrint(
              'Agent status changed event received! Refreshing device list.',
            );
            deviceProvider.fetchDevices(isManualRefresh: true);
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
    _reconnectTimer?.cancel();
    _webSocketService.disconnect();
    _messageSubscription?.cancel();
  }

  void sendCommand(String prompt) {
    if (!isAgentOnline) {
      _messages.add(
        GenericMessage("Error: No online agent available to send command."),
      );
      notifyListeners();
      return;
    }
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

  void clearConfirmation() {
    _isConfirmationPending = false;
    _pendingIntent = null;
    _pendingExplanation = null;
    notifyListeners();
  }

  @override
  void dispose() {
    authProvider.removeListener(_onAuthChanged);
    deviceProvider.removeListener(notifyListeners);
    _reconnectTimer?.cancel();
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }
}
