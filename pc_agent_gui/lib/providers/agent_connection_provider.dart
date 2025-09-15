import 'dart:async';
import 'package:flutter/material.dart';
import '../services/agent_service.dart';

class AgentConnectionProvider with ChangeNotifier {
  StreamSubscription? _agentEventSubscription;

  String _statusMessage = 'Initializing...';
  String get statusMessage => _statusMessage;

  AgentConnectionProvider() {
    _listenToAgentEvents();
  }

  void _listenToAgentEvents() {
    _agentEventSubscription = agentService.events.listen((event) {
      final type = event['type'] as String?;
      final data = event['data'] as Map<String, dynamic>? ?? {};

      bool shouldNotify = false;

      switch (type) {
        case 'status_update':
          final newMessage = data['message'] as String? ?? 'Unknown status';
          if (_statusMessage != newMessage) {
            _statusMessage = newMessage;
            shouldNotify = true;
          }
          break;
        case 'error':
          final errorMessage =
              data['message'] as String? ?? 'An agent error occurred.';
          if (_statusMessage != errorMessage) {
            _statusMessage = errorMessage;
            shouldNotify = true;
          }
          break;
      }

      if (shouldNotify) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _agentEventSubscription?.cancel();
    super.dispose();
  }
}
