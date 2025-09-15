import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    debugPrint(" paranoid_log [AuthProvider]: INIT");
    _initializeAgentDeviceId();
    agentService.startAgent();
    _listenToAgentEvents();
  }

  Future<void> hardLogout() async {
    debugPrint(" paranoid_log [AuthProvider]: hardLogout() called.");
    await _authRepository.logout();
    const deviceIdKey = 'agent_device_id';
    await _authRepository.deleteValue(deviceIdKey);
    agentService.sendCommand('logout');
  }

  Future<void> logout() async {
    debugPrint(" paranoid_log [AuthProvider]: logout() called.");
    await _authRepository.logout();
    agentService.sendCommand('logout');
  }

  void _listenToAgentEvents() {
    _agentEventSubscription = agentService.events.listen((event) {
      final type = event['type'] as String?;
      final data = event['data'] as Map<String, dynamic>? ?? {};
      debugPrint(" paranoid_log [AuthProvider]: Received agent event: $type");

      bool needsNotify = false;
      switch (type) {
        case 'status_update':
          final status = data['status'] as String?;
          if (status == 'connected') {
            if (!_isAuthenticated) {
              debugPrint(
                " paranoid_log [AuthProvider]: Event changed state: isAuthenticated -> true",
              );
              _isAuthenticated = true;
              _errorMessage = null;
              needsNotify = true;
            }
          } else if (status == 'logged_out' ||
              status == 'ready' ||
              status == 'stopped') {
            if (_isAuthenticated) {
              debugPrint(
                " paranoid_log [AuthProvider]: Event changed state: isAuthenticated -> false",
              );
              _isAuthenticated = false;
              needsNotify = true;
            }
          }
          if (_isLoading) {
            debugPrint(
              " paranoid_log [AuthProvider]: Event changed state: isLoading -> false",
            );
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
            debugPrint(
              " paranoid_log [AuthProvider]: Event changed state: isLoading -> true",
            );
            _isLoading = true;
            needsNotify = true;
          }
          break;
      }
      if (needsNotify) {
        debugPrint(" paranoid_log [AuthProvider]: Notifying listeners...");
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
    debugPrint(" paranoid_log [AuthProvider]: tryAutoLogin() called.");
    String? storedToken;
    try {
      storedToken = await _authRepository.getToken();
    } on PlatformException catch (e) {
      debugPrint(
        " paranoid_log [AuthProvider]: Storage corrupt. Calling hardLogout().",
      );
      await hardLogout();
      return;
    }

    if (storedToken != null) {
      debugPrint(
        " paranoid_log [AuthProvider]: Token found. Sending auto_login command.",
      );
      if (_agentDeviceId == null) await _initializeAgentDeviceId();
      agentService.sendCommand('auto_login_with_token', {
        'token': storedToken,
        'deviceId': _agentDeviceId,
      });
    } else {
      debugPrint(" paranoid_log [AuthProvider]: No token found.");
    }
  }

  Future<void> login(String username, String password) async {
    if (_isLoading) return;
    debugPrint(" paranoid_log [AuthProvider]: login() called.");
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_agentDeviceId == null) await _initializeAgentDeviceId();
      final jwt = await _authRepository.loginAndGetToken(username, password);
      await _authRepository.saveToken(jwt);
      debugPrint(
        " paranoid_log [AuthProvider]: Login API success. Sending auto_login command.",
      );
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
