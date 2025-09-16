import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../repositories/command_repository.dart';
import '../services/connection_status.dart';
import '../services/device_identity_service.dart';
import 'auth_provider.dart';

class ConnectionProvider with ChangeNotifier {
  final Stopwatch _logStopwatch = Stopwatch()..start();
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
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-INIT] ConnectionProvider initialized. Adding listener to AuthProvider.',
    );
    authProvider.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-AUTH-CHANGED] _onAuthChanged triggered. AuthProvider.isAuthenticated: ${authProvider.isAuthenticated}.',
    );
    if (authProvider.isAuthenticated) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-AUTH-CHANGED] User is authenticated. Calling _startListeningAndConnect.',
      );
      _startListeningAndConnect();
    } else {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-AUTH-CHANGED] User is NOT authenticated. Calling _stopListening and updating status.',
      );
      _stopListening();
      _updateStatus(ConnectionStatus.offline);
      _updateAgentStatus(false);
    }
  }

  void _startListeningAndConnect() async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-START-LISTEN] _startListeningAndConnect called.',
    );
    if (_statusSubscription != null || _messageSubscription != null) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-START-LISTEN] Subscriptions already exist. Aborting.',
      );
      return;
    }

    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-START-LISTEN] Setting up new subscriptions to repository streams.',
    );
    _statusSubscription = commandRepository.status.listen(_onStatusChanged);
    _messageSubscription = commandRepository.messages.listen(
      _onMessageReceived,
    );

    if (authProvider.token == null) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-START-LISTEN] AuthProvider token is null. Cannot connect.',
      );
      return;
    }
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-START-LISTEN] Getting deviceId...',
    );
    final deviceId = await _identityService.getOrCreateDeviceId();
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-START-LISTEN] Got deviceId: $deviceId. Calling commandRepository.connect().',
    );
    commandRepository.connect(authProvider.token!, deviceId);
  }

  void _stopListening() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-STOP-LISTEN] _stopListening called.',
    );
    commandRepository.dispose();
    _statusSubscription?.cancel();
    _messageSubscription?.cancel();
    _statusSubscription = null;
    _messageSubscription = null;
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-STOP-LISTEN] Listening stopped and subscriptions cancelled.',
    );
  }

  void _onStatusChanged(ConnectionStatus status) {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-STATUS-CHANGED] _onStatusChanged received new status: $status. Current status: $_connectionStatus.',
    );
    if (_connectionStatus == status) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-STATUS-CHANGED] New status is the same as the old one. No update needed.',
      );
      return;
    }
    _updateStatus(status);
    if (status == ConnectionStatus.offline ||
        status == ConnectionStatus.connecting) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-STATUS-CHANGED] Status is offline or connecting. Forcing agent status to offline.',
      );
      _updateAgentStatus(false);
    }
  }

  void _onMessageReceived(String messageString) {
    // This can be noisy, so we log only the relevant message.
    try {
      final data = json.decode(messageString);
      if (data['type'] == 'agent_status_changed') {
        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-MSG-RECV] Received "agent_status_changed" message: $messageString',
        );
        final newStatus = (data['status'] as String?) == 'ONLINE';
        _updateAgentStatus(newStatus);
      }
    } catch (e) {
      // Pass on JSON errors, not relevant for this log.
    }
  }

  void _updateStatus(ConnectionStatus newStatus) {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-UPDATE-STATUS] _updateStatus called with new status: $newStatus. Current status: $_connectionStatus.',
    );
    if (_connectionStatus != newStatus) {
      _connectionStatus = newStatus;
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-UPDATE-STATUS] Status changed. Notifying listeners.',
      );
      notifyListeners();
    }
  }

  void _updateAgentStatus(bool newStatus) {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-UPDATE-AGENT-STATUS] _updateAgentStatus called with new status: $newStatus. Current status: $_isAgentOnline.',
    );
    if (_isAgentOnline != newStatus) {
      _isAgentOnline = newStatus;
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-UPDATE-AGENT-STATUS] Agent status updated to: $_isAgentOnline. Notifying listeners.',
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-DISPOSE] ConnectionProvider disposed.',
    );
    authProvider.removeListener(_onAuthChanged);
    _stopListening();
    super.dispose();
  }
}
