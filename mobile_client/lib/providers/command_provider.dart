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
  StreamSubscription? _messageSubscription, _statusSubscription;
  VoidCallback? onAuthError;
  bool _isConfirmationPending = false;
  String? _pendingIntent, _pendingExplanation, _pendingCommandId;
  bool _isAgentOnline = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.offline;
  final Map<String, List<AppMessage>> _messageGroups = {};
  final List<String> _commandOrder = [];

  String? _sendingCommandId;
  bool get isSendingCommand => _sendingCommandId != null;

  Map<String, List<AppMessage>> get messageGroups => _messageGroups;
  List<String> get commandOrder => _commandOrder;
  bool get isConfirmationPending => _isConfirmationPending;
  String? get pendingIntent => _pendingIntent;
  String? get pendingExplanation => _pendingExplanation;
  bool get isAgentOnline => _isAgentOnline;
  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == ConnectionStatus.online;

  CommandProvider({required this.authProvider, required this.deviceProvider}) {
    authProvider.addListener(_onAuthChanged);
    _statusSubscription = _webSocketService.status.listen(_onStatusChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    if (authProvider.isAuthenticated) {
      Future.microtask(() => deviceProvider.fetchDevices());
      _connectAndListen();
    } else {
      _isAgentOnline = false;
      _messageGroups.clear();
      _commandOrder.clear();
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
          final msgType = data['type'] as String?;
          final commandId = data['commandId'] as String?;

          if (commandId != null && commandId == _sendingCommandId) {
            _sendingCommandId = null;
          }

          if (msgType == 'agent_status_changed') {
            final newStatus = (data['status'] as String?) == 'ONLINE';
            if (_isAgentOnline != newStatus) {
              _isAgentOnline = newStatus;
              notifyListeners();
            }
            return;
          }

          if (commandId != null) {
            if (!_messageGroups.containsKey(commandId)) {
              debugPrint(
                "Received message for an unknown commandId: $commandId. Ignoring.",
              );
              return;
            }
            final message = AppMessage.fromJson(messageString, data);
            _messageGroups[commandId]!.add(message);

            if (msgType == 'confirmation_required') {
              _isConfirmationPending = true;
              _pendingIntent = data['intent'] as String?;
              _pendingExplanation = data['explanation'] as String?;
              _pendingCommandId = commandId;
            }
          } else {
            debugPrint("Received message without commandId: $messageString");
          }
        } catch (e) {
          debugPrint("Error processing message: $e");
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
    if (!isAgentOnline || isSendingCommand) return;

    final commandId = _uuid.v4();
    final commandData = {
      'type': 'command',
      'prompt': prompt,
      'commandId': commandId,
    };
    final commandJson = json.encode(commandData);

    _sendingCommandId = commandId;

    _commandOrder.add(commandId);
    _messageGroups[commandId] = [UserCommandMessage(prompt)];

    _webSocketService.sendCommand(commandJson);
    notifyListeners();
  }

  void sendConfirmationResponse(bool approved) {
    if (!_isConfirmationPending || _pendingCommandId == null) return;
    final responseJson = json.encode({
      "type": "confirmation_response",
      "approved": approved,
      "intent": _pendingIntent,
    });
    final userResponse = GenericMessage(
      'You: Responded with "${approved ? 'APPROVE' : 'CANCEL'}" for intent: "$_pendingIntent"',
    );
    _messageGroups[_pendingCommandId!]?.add(userResponse);
    _webSocketService.sendCommand(responseJson);
    clearConfirmation();
  }

  void clearConfirmation() {
    _isConfirmationPending = false;
    _pendingIntent = null;
    _pendingExplanation = null;
    _pendingCommandId = null;
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
