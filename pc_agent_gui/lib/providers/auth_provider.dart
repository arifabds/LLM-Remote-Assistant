import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../services/agent_service.dart';
import '../repositories/auth_repository.dart';
import 'device_provider.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  StreamSubscription? _agentEventSubscription;
  DeviceProvider? _deviceProvider;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _agentDeviceId;

  final Stopwatch _stopwatch = Stopwatch()..start();
  void _log(String message) {
    debugPrint(
      'paranoid_log [${_stopwatch.elapsedMilliseconds}ms | AuthProvider]: $message',
    );
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _log("INIT");
    _initializeAgentDeviceId();
    agentService.startAgent();
    _listenToAgentEvents();
  }

  void setDeviceProvider(DeviceProvider dp) {
    _log("setDeviceProvider() called.");
    _deviceProvider = dp;
  }

  void _listenToAgentEvents() {
    _agentEventSubscription = agentService.events.listen((event) {
      final type = event['type'] as String?;
      final data = event['data'] as Map<String, dynamic>? ?? {};
      _log("Received agent event: $type");

      bool needsNotify = false;
      switch (type) {
        case 'status_update':
          final status = data['status'] as String?;
          if (status == 'connected') {
            if (!_isAuthenticated) {
              _log(
                "Event changed state: isAuthenticated -> true. Calling _deviceProvider.onLogin().",
              );
              _isAuthenticated = true;
              _errorMessage = null;
              needsNotify = true;
              _deviceProvider?.onLogin();
            }
          } else if (status == 'logged_out' || status == 'stopped') {
            if (_isAuthenticated) {
              _log(
                "Event changed state: isAuthenticated -> false. Calling _deviceProvider.onLogout().",
              );
              _isAuthenticated = false;
              needsNotify = true;
              _deviceProvider?.onLogout();
            }
          }
          if (_isLoading &&
              (status == 'connected' ||
                  status == 'logged_out' ||
                  status == 'stopped' ||
                  status == 'ready')) {
            _log("Event changed state: isLoading -> false");
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
            _log("Event changed state: isLoading -> true");
            _isLoading = true;
            needsNotify = true;
          }
          break;
      }
      if (needsNotify) {
        _log(
          "Notifying listeners. New state: isAuthenticated=$_isAuthenticated, isLoading=$_isLoading",
        );
        notifyListeners();
      }
    });
  }

  Future<void> login(String username, String password) async {
    if (_isLoading) return;
    _log("login() called.");
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_agentDeviceId == null) await _initializeAgentDeviceId();
      final jwt = await _authRepository.loginAndGetToken(username, password);
      await _authRepository.saveToken(jwt);
      _log("Login API success. Sending auto_login command.");
      agentService.sendCommand('auto_login_with_token', {
        'token': jwt,
        'deviceId': _agentDeviceId,
      });
      // KESİN ÇÖZÜM: Token kaydedildikten hemen sonra DeviceProvider'ı tetiklemiyoruz,
      // 'connected' olayının bunu yapmasını bekliyoruz.
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> hardLogout() async {
    _log("hardLogout() called.");
    await _authRepository.logout();
    const deviceIdKey = 'agent_device_id';
    await _authRepository.deleteValue(deviceIdKey);
    agentService.sendCommand('logout');
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
    _log("tryAutoLogin() called.");
    String? storedToken;
    try {
      storedToken = await _authRepository.getToken();
    } on PlatformException catch (e) {
      _log("Storage corrupt. Calling hardLogout(). Error: $e");
      await hardLogout();
      return;
    }

    if (storedToken != null) {
      _log("Token found. Sending auto_login command.");
      if (_agentDeviceId == null) await _initializeAgentDeviceId();
      agentService.sendCommand('auto_login_with_token', {
        'token': storedToken,
        'deviceId': _agentDeviceId,
      });
    } else {
      _log("No token found.");
    }
  }

  @override
  void dispose() {
    _agentEventSubscription?.cancel();
    super.dispose();
  }
}
