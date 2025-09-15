import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/messages/app_message.dart';
import '../models/messages/generic_message.dart';
import '../models/messages/user_command_message.dart';
import '../repositories/command_repository.dart';
import 'auth_provider.dart';
import 'connection_provider.dart';

class CommandProvider with ChangeNotifier {
  final CommandRepository commandRepository;
  final AuthProvider authProvider;
  final ConnectionProvider connectionProvider;
  final _uuid = const Uuid();

  StreamSubscription? _messageSubscription;
  VoidCallback? onAuthError;

  bool _isConfirmationPending = false;
  String? _pendingIntent, _pendingExplanation, _pendingCommandId;
  final Map<String, List<AppMessage>> _messageGroups = {};
  final List<String> _commandOrder = [];
  String? _sendingCommandId;

  bool get isSendingCommand => _sendingCommandId != null;
  Map<String, List<AppMessage>> get messageGroups => _messageGroups;
  List<String> get commandOrder => _commandOrder;
  bool get isConfirmationPending => _isConfirmationPending;
  String? get pendingIntent => _pendingIntent;
  String? get pendingExplanation => _pendingExplanation;
  bool get isAgentOnline => connectionProvider.isAgentOnline;
  CommandProvider({
    required this.authProvider,
    required this.connectionProvider,
    required this.commandRepository,
  }) {
    authProvider.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    if (authProvider.isAuthenticated) {
      _startListening();
    } else {
      _stopListening();
      _messageGroups.clear();
      _commandOrder.clear();
      _sendingCommandId = null;
      clearConfirmation();
    }
  }

  void _startListening() {
    _messageSubscription?.cancel();
    _messageSubscription = commandRepository.messages.listen(
      _onMessageReceived,
    );
  }

  void _stopListening() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
  }

  void _onMessageReceived(String messageString) {
    try {
      final data = json.decode(messageString);
      final msgType = data['type'] as String?;
      final commandId = data['commandId'] as String?;

      if (commandId != null && commandId == _sendingCommandId) {
        _sendingCommandId = null;
      }

      if (commandId != null) {
        if (!_messageGroups.containsKey(commandId)) return;

        final message = AppMessage.fromJson(messageString, data);
        _messageGroups[commandId]!.add(message);

        if (msgType == 'confirmation_required') {
          _isConfirmationPending = true;
          _pendingIntent = data['intent'] as String?;
          _pendingExplanation = data['explanation'] as String?;
          _pendingCommandId = commandId;
        }
      }
    } catch (e) {
      debugPrint("Error processing message in CommandProvider: $e");
    }
    notifyListeners();
  }

  void sendCommand(String prompt) {
    if (!connectionProvider.isAgentOnline || isSendingCommand) return;

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

    commandRepository.send(commandJson);
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
    commandRepository.send(responseJson);
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
    _stopListening();
    super.dispose();
  }
}
