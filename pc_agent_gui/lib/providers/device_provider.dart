import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/device_repository.dart';

class DeviceProvider with ChangeNotifier {
  final AuthRepository authRepository;
  final DeviceRepository deviceRepository;

  List<Device> _pairedMobileDevices = [];
  String? _pairingToken;
  String? _errorMessage;
  bool _isLoading = false;

  final Stopwatch _stopwatch = Stopwatch()..start();
  void _log(String message) {
    debugPrint(
      'paranoid_log [${_stopwatch.elapsedMilliseconds}ms | DeviceProvider]: $message',
    );
  }

  List<Device> get pairedMobileDevices => _pairedMobileDevices;
  String? get pairingToken => _pairingToken;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  DeviceProvider({
    required this.authRepository,
    required this.deviceRepository,
  }) {
    _log("INIT");
  }

  void onLogin() {
    _log("onLogin() called by AuthProvider.");
    fetchPairedMobileDevices();
  }

  void onLogout() {
    _log("onLogout() called by AuthProvider. Clearing state.");
    clearState();
  }

  Future<void> fetchPairedMobileDevices() async {
    if (_isLoading) {
      _log("fetchPairedMobileDevices SKIPPED (already loading).");
      return;
    }
    _log("fetchPairedMobileDevices STARTED.");
    _isLoading = true;
    _errorMessage = null;
    _log("Notifying listeners (isLoading = true).");
    notifyListeners();

    try {
      _log("Awaiting device list from repository...");
      final devices = await deviceRepository.getPairedMobileDevices();
      _log("Fetched ${devices.length} devices.");
      _pairedMobileDevices = devices;

      if (_pairedMobileDevices.isEmpty) {
        _log("Device list is empty. Awaiting new pairing token...");
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
          _log("New pairing token received: ${_pairingToken != null}");
        } else {
          _log("Could not get token or deviceId to fetch new pairing token.");
        }
      } else {
        _pairingToken = null;
        _log("Paired devices exist. Pairing token set to null.");
      }
    } catch (e) {
      _errorMessage = 'Could not fetch devices: $e';
      _pairedMobileDevices = [];
      _pairingToken = null;
      _log("ERROR during fetch: $e");
    }
    _isLoading = false;
    _log(
      "fetchPairedMobileDevices FINISHED. Final state: isLoading=$_isLoading, pairingToken is null=${_pairingToken == null}. Notifying listeners.",
    );
    notifyListeners();
  }

  void unpairMobileDevice(int deviceId) async {
    _log("unpairMobileDevice called for deviceId: $deviceId");
    _errorMessage = null;
    try {
      await deviceRepository.unpairMobileDevice(deviceId);
      _pairedMobileDevices.removeWhere((d) => d.id == deviceId);
      _log(
        "Local device list updated. Device count: ${_pairedMobileDevices.length}",
      );
      if (_pairedMobileDevices.isEmpty) {
        _log("Last device unpaired, fetching new pairing token...");
        await fetchPairedMobileDevices();
      }
    } catch (e) {
      _errorMessage = 'Failed to unpair device: $e';
      _log("ERROR during unpair: $e");
    } finally {
      _log("Unpair operation finished. Notifying listeners.");
      notifyListeners();
    }
  }

  void clearState() {
    _log("clearState() called.");
    _pairedMobileDevices = [];
    _pairingToken = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
