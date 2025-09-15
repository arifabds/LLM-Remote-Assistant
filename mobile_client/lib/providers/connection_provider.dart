import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../repositories/command_repository.dart';
import '../services/connection_status.dart';
import '../services/device_identity_service.dart';
import 'auth_provider.dart';

class ConnectionProvider with ChangeNotifier {
  final AuthProvider authProvider;
  final CommandRepository commandRepository;
  final DeviceIdentityService _identityService = DeviceIdentityService();

  StreamSubscription? _statusSubscription;
  StreamSubscription? _messageSubscription;

  ConnectionStatus _connectionStatus = ConnectionStatus.offline;
  bool _isAgentOnline = false;

  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isAgentOnline => _isAgentOnline;
  bool get isConnected => _connectionStatus == ConnectionStatus.online;

  ConnectionProvider({
    required this.authProvider,
    required this.commandRepository,
  }) {
    authProvider.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    if (authProvider.isAuthenticated) {
      _startListeningAndConnect();
    } else {
      _stopListening();
      _updateStatus(ConnectionStatus.offline);
      _updateAgentStatus(false);
    }
  }

  void _startListeningAndConnect() async {
    if (_statusSubscription != null || _messageSubscription != null) return;

    _statusSubscription = commandRepository.status.listen(_onStatusChanged);
    _messageSubscription = commandRepository.messages.listen(
      _onMessageReceived,
    );

    if (authProvider.token == null) return;
    final deviceId = await _identityService.getOrCreateDeviceId();
    commandRepository.connect(authProvider.token!, deviceId);
  }

  void _stopListening() {
    commandRepository.dispose();
    _statusSubscription?.cancel();
    _messageSubscription?.cancel();
    _statusSubscription = null;
    _messageSubscription = null;
  }

  void _onStatusChanged(ConnectionStatus status) {
    if (_connectionStatus == status) return;
    _updateStatus(status);
    if (status == ConnectionStatus.offline ||
        status == ConnectionStatus.connecting) {
      _updateAgentStatus(false);
    }
  }

  void _onMessageReceived(String messageString) {
    try {
      final data = json.decode(messageString);
      if (data['type'] == 'agent_status_changed') {
        final newStatus = (data['status'] as String?) == 'ONLINE';
        _updateAgentStatus(newStatus);
      }
    } catch (e) {
      // Pass
    }
  }

  void _updateStatus(ConnectionStatus newStatus) {
    if (_connectionStatus != newStatus) {
      _connectionStatus = newStatus;
      notifyListeners();
    }
  }

  void _updateAgentStatus(bool newStatus) {
    if (_isAgentOnline != newStatus) {
      _isAgentOnline = newStatus;
      debugPrint(
        "[ConnectionProvider] Agent status updated to: $_isAgentOnline",
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    authProvider.removeListener(_onAuthChanged);
    _stopListening();
    super.dispose();
  }
}
