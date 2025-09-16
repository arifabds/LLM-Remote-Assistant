import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/device_model.dart'; // Güncellenmiş modeli import et
import '../repositories/command_repository.dart';
import '../services/connection_status.dart';
import '../services/device_identity_service.dart';
import 'auth_provider.dart';
import 'device_provider.dart';

class ConnectionProvider with ChangeNotifier {
  final Stopwatch _logStopwatch = Stopwatch()..start();
  final AuthProvider authProvider;
  final DeviceProvider deviceProvider;
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
    required this.deviceProvider,
    required this.commandRepository,
  }) {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-INIT] ConnectionProvider initialized.',
    );
    authProvider.addListener(_onAuthChanged);
    // ================== ÇÖZÜM KODU (BAŞLANGIÇ) ==================
    deviceProvider.addListener(_onDeviceProviderChanged);
    // ==========================================================
    _onAuthChanged();
  }

  // ================== ÇÖZÜM KODU (YENİ METOD) ==================
  void _onDeviceProviderChanged() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-P.1.2-TRIGGER] _onDeviceProviderChanged triggered because DeviceProvider notified listeners.',
    );
    // DeviceProvider'ın listesindeki cihazlara bakarak ajanın online olup olmadığını kontrol et.
    // Bu, "pull" mekanizmasıdır.
    final bool isAnyAgentOnlineInList = deviceProvider.devices.any(
      (d) =>
          d.clientType == ClientType.AGENT && d.status == DeviceStatus.ONLINE,
    );

    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-P.1.2-CHECK] Checking devices from DeviceProvider. Found any online agent: $isAnyAgentOnlineInList',
    );

    // Eğer `fetchDevices` sonrası listede online bir ajan varsa
    // ve bizim mevcut durumumuz `false` ise, durumumuzu güncelle.
    if (isAnyAgentOnlineInList && !_isAgentOnline) {
      _updateAgentStatus(true);
    }
  }
  // ============================================================

  void _onAuthChanged() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-AUTH-CHANGED] _onAuthChanged triggered. AuthProvider.isAuthenticated: ${authProvider.isAuthenticated}.',
    );
    if (authProvider.isAuthenticated) {
      _startListeningAndConnect();
    } else {
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
    if (_connectionStatus == status) return;

    _updateStatus(status);
    if (status == ConnectionStatus.offline ||
        status == ConnectionStatus.connecting) {
      _updateAgentStatus(false);
    }

    // ================== ÇÖZÜM KODU ==================
    if (status == ConnectionStatus.online) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-P.1.1-TRIGGER] Connection is now ONLINE. Proactively triggering deviceProvider.fetchDevices().',
      );
      deviceProvider.fetchDevices();
    }
    // ===============================================
  }

  void _onMessageReceived(String messageString) {
    // Bu metod "push" mekanizması olarak kalmaya devam ediyor.
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
      // Pass
    }
  }

  void _updateStatus(ConnectionStatus newStatus) {
    if (_connectionStatus != newStatus) {
      _connectionStatus = newStatus;
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-CONNPROV-UPDATE-STATUS] Status changed to $_connectionStatus. Notifying listeners.',
      );
      notifyListeners();
    }
  }

  void _updateAgentStatus(bool newStatus) {
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
    deviceProvider.removeListener(_onDeviceProviderChanged);
    _stopListening();
    super.dispose();
  }
}
