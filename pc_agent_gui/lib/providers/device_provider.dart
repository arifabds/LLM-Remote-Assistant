import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/device_repository.dart';
import 'auth_provider.dart';

class DeviceProvider with ChangeNotifier {
  final AuthProvider authProvider;
  final AuthRepository authRepository;
  final DeviceRepository deviceRepository;

  List<Device> _pairedMobileDevices = [];
  String? _pairingToken;
  String? _errorMessage;

  List<Device> get pairedMobileDevices => _pairedMobileDevices;
  String? get pairingToken => _pairingToken;
  String? get errorMessage => _errorMessage;

  DeviceProvider({
    required this.authProvider,
    required this.authRepository,
    required this.deviceRepository,
  }) {
    authProvider.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (authProvider.isAuthenticated) {
      fetchPairedMobileDevices();
    } else {
      _pairedMobileDevices = [];
      _pairingToken = null;
      notifyListeners();
    }
  }

  Future<void> fetchPairedMobileDevices() async {
    _errorMessage = null;
    try {
      _pairedMobileDevices = await deviceRepository.getPairedMobileDevices();

      if (_pairedMobileDevices.isEmpty && authProvider.isAuthenticated) {
        final token = await authRepository.getToken();
        final agentDeviceId = await authRepository.getDeviceId(
          'agent_device_id',
        );

        if (token != null && agentDeviceId != null) {
          final backendPairingToken = await authRepository.initiatePairing(
            token: token,
            agentDeviceId: agentDeviceId,
            agentDeviceName: 'My Windows Agent',
          );
          _pairingToken = backendPairingToken;
        }
      } else {
        _pairingToken = null;
      }
    } catch (e) {
      _errorMessage = 'Could not fetch devices or get pairing token: $e';
      _pairedMobileDevices = [];
      _pairingToken = null;
    }
    notifyListeners();
  }

  Future<void> unpairMobileDevice(int deviceId) async {
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
      notifyListeners();
    }
  }

  @override
  void dispose() {
    authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}
