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
    debugPrint(" paranoid_log [DeviceProvider]: INIT");
    authProvider.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    debugPrint(
      " paranoid_log [DeviceProvider]: _onAuthChanged triggered. isAuthenticated: ${authProvider.isAuthenticated}",
    );
    if (authProvider.isAuthenticated) {
      fetchPairedMobileDevices();
    } else {
      debugPrint(
        " paranoid_log [DeviceProvider]: Auth is false. Clearing state.",
      );
      clearState();
    }
  }

  Future<void> fetchPairedMobileDevices() async {
    if (_isLoading) {
      debugPrint(
        " paranoid_log [DeviceProvider]: fetchPairedMobileDevices SKIPPED (already loading).",
      );
      return;
    }
    debugPrint(
      " paranoid_log [DeviceProvider]: fetchPairedMobileDevices STARTED.",
    );
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint(
        " paranoid_log [DeviceProvider]: Awaiting device list from repository...",
      );
      final devices = await deviceRepository.getPairedMobileDevices();
      debugPrint(
        " paranoid_log [DeviceProvider]: Fetched ${devices.length} devices.",
      );
      _pairedMobileDevices = devices;

      if (_pairedMobileDevices.isEmpty) {
        debugPrint(
          " paranoid_log [DeviceProvider]: Device list is empty. Awaiting new pairing token...",
        );
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
          debugPrint(
            " paranoid_log [DeviceProvider]: New pairing token received: ${_pairingToken != null}",
          );
        } else {
          debugPrint(
            " paranoid_log [DeviceProvider]: Could not get token or deviceId to fetch new pairing token.",
          );
        }
      } else {
        _pairingToken = null;
        debugPrint(
          " paranoid_log [DeviceProvider]: Paired devices exist. Pairing token set to null.",
        );
      }
    } catch (e) {
      _errorMessage = 'Could not fetch devices: $e';
      _pairedMobileDevices = [];
      _pairingToken = null;
      debugPrint(" paranoid_log [DeviceProvider]: ERROR during fetch: $e");
    } finally {
      _isLoading = false;
      debugPrint(
        " paranoid_log [DeviceProvider]: fetchPairedMobileDevices FINISHED. Final state: isLoading=$_isLoading, pairingToken is null=${_pairingToken == null}. Notifying listeners.",
      );
      notifyListeners();
    }
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
