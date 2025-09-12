import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/agent_service.dart';
import '../services/auth_service.dart';
import '../models/device_model.dart';
import '../services/device_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _localAuthService = AuthService();
  final DeviceService _deviceService = DeviceService();
  StreamSubscription? _agentEventSubscription;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _statusMessage = 'Initializing...';
  String? _pairingToken;
  String? _agentDeviceId;

  List<Device> _pairedDevices = [];

  List<Device> get pairedDevices => _pairedDevices;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get statusMessage => _statusMessage;
  String? get pairingToken => _pairingToken;

  AuthProvider() {
    _initializeAgentDeviceId();
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
            _fetchPairedDevices();
          } else if (status == 'logged_out' ||
              status == 'ready' ||
              status == 'stopped') {
            _isAuthenticated = false;
            _pairingToken = null;
            _pairedDevices = [];
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

  Future<void> _initializeAgentDeviceId() async {
    const deviceIdKey = 'agent_device_id';
    String? deviceId = await _localAuthService.getDeviceId(deviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _localAuthService.saveDeviceId(deviceIdKey, deviceId);
    }
    _agentDeviceId = deviceId;
  }

  Future<void> tryAutoLogin() async {
    final storedToken = await _localAuthService.getToken();
    if (storedToken != null) {
      if (_agentDeviceId == null) await _initializeAgentDeviceId();
      agentService.sendCommand('auto_login_with_token', {
        'token': storedToken,
        'deviceId': _agentDeviceId,
      });
    }
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_agentDeviceId == null) {
        await _initializeAgentDeviceId();
      }

      final jwt = await _localAuthService.loginAndGetToken(username, password);
      _pairingToken = const Uuid().v4();

      await _localAuthService.initiatePairing(
        token: jwt,
        pairingToken: _pairingToken!,
        agentDeviceId: _agentDeviceId!,
        agentDeviceName: 'My Windows Agent',
      );

      await _localAuthService.saveToken(jwt);
      agentService.sendCommand('auto_login_with_token', {
        'token': jwt,
        'deviceId': _agentDeviceId,
      });
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
    notifyListeners();
  }

  Future<void> _fetchPairedDevices() async {
    try {
      _pairedDevices = await _deviceService.getPairedMobileDevices();
    } catch (e) {
      _errorMessage = 'Could not fetch paired devices: $e';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _agentEventSubscription?.cancel();
    super.dispose();
  }
}
