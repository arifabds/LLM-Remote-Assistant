import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final _storage = const FlutterSecureStorage();

  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  String? get token => _token;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final receivedToken = await _authService.login(
        username: username,
        password: password,
      );
      _token = receivedToken;
      await _storage.write(key: 'jwt', value: _token);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.register(username: username, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _isLoading = false;
    await _storage.delete(key: 'jwt');
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final storedToken = await _storage.read(key: 'jwt');
    if (storedToken == null) {
      return false;
    }
    _token = storedToken;
    notifyListeners();
    return true;
  }
}
