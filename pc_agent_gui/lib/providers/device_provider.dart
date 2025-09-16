import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/device_repository.dart';
import 'auth_provider.dart';

class DeviceProvider with ChangeNotifier {
  AuthProvider authProvider;
  final AuthRepository authRepository;
  final DeviceRepository deviceRepository;

  List<Device> _pairedMobileDevices = [];
  String? _pairingToken;
  String? _errorMessage;
  bool _isLoading = false;

  List<Device> get pairedMobileDevices => _pairedMobileDevices;
  String? get pairingToken => _pairingToken;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  DeviceProvider({
    required this.authProvider,
    required this.authRepository,
    required this.deviceRepository,
  }) {
    authProvider.addListener(_onAuthChanged);
  }

  void updateAuthProvider(AuthProvider newAuthProvider) {
    if (authProvider != newAuthProvider) {
      authProvider.removeListener(_onAuthChanged);
      authProvider = newAuthProvider;
      authProvider.addListener(_onAuthChanged);
      _onAuthChanged();
    }
  }

  void _onAuthChanged() {
    if (authProvider.isAuthenticated) {
      fetchPairedMobileDevices();
    } else {
      clearState();
    }
  }

  Future<void> fetchPairedMobileDevices() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final devices = await deviceRepository.getPairedMobileDevices();
      _pairedMobileDevices = devices;
      if (_pairedMobileDevices.isEmpty && authProvider.isAuthenticated) {
        final token = await authRepository.getToken();
        final agentDeviceId = await authRepository.getDeviceId(
          'agent_device_id',
        );
        if (token != null && agentDeviceId != null) {
          _pairingToken = await authRepository.initiatePairing(
            token: token,
            agentDeviceId: agentDeviceId,
            agentDeviceName: 'My Windows Agent',
          );
        }
      } else {
        _pairingToken = null;
      }
    } catch (e) {
      _errorMessage = 'Could not fetch devices: $e';
      _pairedMobileDevices = [];
      _pairingToken = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void unpairMobileDevice(int deviceId) async {
    _errorMessage = null;
    try {
      await deviceRepository.unpairMobileDevice(deviceId);
      _pairedMobileDevices.removeWhere((d) => d.id == deviceId);

      if (_pairedMobileDevices.isEmpty) {
        await fetchPairedMobileDevices();
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to unpair device: $e';
    } finally {
      notifyListeners();
    }
  }

  void clearState() {
    _pairedMobileDevices = [];
    _pairingToken = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}
