import 'dart:async';
import 'package:flutter/material.dart';
import '../services/agent_service.dart';
import 'auth_provider.dart';

class AgentConnectionProvider with ChangeNotifier {
  StreamSubscription? _agentEventSubscription;
  AuthProvider authProvider;

  String _statusMessage = 'Initializing...';
  String get statusMessage => _statusMessage;

  AgentConnectionProvider({required this.authProvider}) {
    authProvider.addListener(_onAuthChanged);
    _listenToAgentEvents();
  }

  // ProxyProvider için update metodu
  void updateAuthProvider(AuthProvider newAuthProvider) {
    if (authProvider != newAuthProvider) {
      authProvider.removeListener(_onAuthChanged);
      authProvider = newAuthProvider;
      authProvider.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    if (authProvider.isLoading) {
      _updateStatusMessage("Logging in...");
    }
  }

  void _listenToAgentEvents() {
    _agentEventSubscription = agentService.events.listen((event) {
      final type = event['type'] as String?;
      final data = event['data'] as Map<String, dynamic>? ?? {};
      switch (type) {
        case 'status_update':
          final newMessage = data['message'] as String? ?? 'Unknown status';
          _updateStatusMessage(newMessage);
          break;
        case 'error':
          final errorMessage =
              data['message'] as String? ?? 'An agent error occurred.';
          _updateStatusMessage(errorMessage);
          break;
      }
    });
  }

  void _updateStatusMessage(String newMessage) {
    if (_statusMessage != newMessage) {
      _statusMessage = newMessage;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    authProvider.removeListener(_onAuthChanged);
    _agentEventSubscription?.cancel();
    super.dispose();
  }
}
