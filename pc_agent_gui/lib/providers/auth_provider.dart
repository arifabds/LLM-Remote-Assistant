import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:uuid/uuid.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _pairingToken;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get pairingToken => _pairingToken;

  AuthProvider() {
    tryAutoLogin();
  }

  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    final token = await _authService.getToken();
    if (token != null) {
      _isAuthenticated = true;
      _generatePairingToken();
    } else {
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.login(username, password);
      _isAuthenticated = true;
      _generatePairingToken();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _clearPairingToken();
    notifyListeners();
  }

  void _generatePairingToken() {
    _pairingToken = _uuid.v4();
  }

  void _clearPairingToken() {
    _pairingToken = null;
  }
}
