import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/agent_service.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _localAuthService = AuthService();
  StreamSubscription? _agentEventSubscription;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _statusMessage = 'Initializing...';
  String? _pairingToken;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get statusMessage => _statusMessage;
  String? get pairingToken => _pairingToken;

  AuthProvider() {
    agentService.startAgent();
    _listenToAgentEvents();
  }

  void _listenToAgentEvents() {
    _agentEventSubscription = agentService.events.listen((event) {
      final type = event['type'] as String?;
      final data = event['data'] as Map<String, dynamic>? ?? {};

      switch (type) {
        case 'status_update':
          _statusMessage = data['message'] as String? ?? 'Unknown status';
          final status = data['status'] as String?;
          if (status == 'connected') {
            _isAuthenticated = true;
            _errorMessage = null;
            _generatePairingToken();
          } else if (status == 'logged_out' ||
              status == 'ready' ||
              status == 'stopped') {
            _isAuthenticated = false;
            _pairingToken = null;
          }
          _isLoading = false;
          break;
        case 'login_failed':
          _errorMessage = data['error'] as String?;
          _isAuthenticated = false;
          _isLoading = false;
          break;
        case 'login_success':
          _errorMessage = null;
          _isLoading = true;
          break;
        case 'error':
          _statusMessage =
              data['message'] as String? ?? 'An agent error occurred.';
          _isLoading = false;
          break;
      }
      notifyListeners();
    });
  }

  Future<void> tryAutoLogin() async {
    final storedToken = await _localAuthService.getToken();
    if (storedToken != null) {
      agentService.sendCommand('auto_login_with_token', {'token': storedToken});
    }
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _localAuthService.login(username, password);
      await tryAutoLogin();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _localAuthService.logout();
    agentService.sendCommand('logout');
  }

  void _generatePairingToken() {
    _pairingToken = const Uuid().v4();
  }

  @override
  void dispose() {
    _agentEventSubscription?.cancel();
    super.dispose();
  }
}
