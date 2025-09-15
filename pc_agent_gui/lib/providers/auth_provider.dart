import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/agent_service.dart';
import '../repositories/auth_repository.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  StreamSubscription? _agentEventSubscription;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _agentDeviceId;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _initializeAgentDeviceId();
    agentService.startAgent();
    _listenToAgentEvents();
  }

  Future<void> hardLogout() async {
    await _authRepository.logout();
    const deviceIdKey = 'agent_device_id';
    await _authRepository.deleteValue(deviceIdKey);
    agentService.sendCommand('logout');
  }

  Future<void> logout() async {
    await _authRepository.logout();
    agentService.sendCommand('logout');
  }

  void _listenToAgentEvents() {
    _agentEventSubscription = agentService.events.listen((event) {
      final type = event['type'] as String?;
      final data = event['data'] as Map<String, dynamic>? ?? {};

      bool needsNotify = false;

      switch (type) {
        case 'status_update':
          final status = data['status'] as String?;
          if (status == 'connected') {
            if (!_isAuthenticated) {
              _isAuthenticated = true;
              _errorMessage = null;
              needsNotify = true;
            }
          } else if (status == 'logged_out' ||
              status == 'ready' ||
              status == 'stopped') {
            if (_isAuthenticated) {
              _isAuthenticated = false;
              needsNotify = true;
            }
          }
          if (_isLoading) {
            _isLoading = false;
            needsNotify = true;
          }
          break;
        case 'login_failed':
          _errorMessage = data['error'] as String?;
          _isAuthenticated = false;
          _isLoading = false;
          needsNotify = true;
          break;
        case 'login_success':
          _errorMessage = null;
          if (!_isLoading) {
            _isLoading = true;
            needsNotify = true;
          }
          break;
      }

      if (needsNotify) {
        notifyListeners();
      }
    });
  }

  Future<void> _initializeAgentDeviceId() async {
    const deviceIdKey = 'agent_device_id';
    String? deviceId = await _authRepository.getDeviceId(deviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _authRepository.saveDeviceId(deviceIdKey, deviceId);
    }
    _agentDeviceId = deviceId;
  }

  Future<void> tryAutoLogin() async {
    final storedToken = await _authRepository.getToken();
    if (storedToken != null) {
      if (_agentDeviceId == null) await _initializeAgentDeviceId();
      agentService.sendCommand('auto_login_with_token', {
        'token': storedToken,
        'deviceId': _agentDeviceId,
      });
    }
  }

  Future<void> login(String username, String password) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_agentDeviceId == null) await _initializeAgentDeviceId();
      final jwt = await _authRepository.loginAndGetToken(username, password);
      await _authRepository.saveToken(jwt);
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

  @override
  void dispose() {
    _agentEventSubscription?.cancel();
    super.dispose();
  }
}
