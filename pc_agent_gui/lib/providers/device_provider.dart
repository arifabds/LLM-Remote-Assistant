import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/device_repository.dart';
import 'auth_provider.dart';

class DeviceProvider with ChangeNotifier {
  final Stopwatch _logStopwatch = Stopwatch()..start();
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
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-INIT] DeviceProvider initialized.',
    );
    authProvider.addListener(_onAuthChanged);
  }

  void updateAuthProvider(AuthProvider newAuthProvider) {
    if (authProvider != newAuthProvider) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-UPDATE-AUTH] AuthProvider instance updated via ProxyProvider.',
      );
      authProvider.removeListener(_onAuthChanged);
      authProvider = newAuthProvider;
      authProvider.addListener(_onAuthChanged);
      _onAuthChanged();
    }
  }

  void _onAuthChanged() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-AUTH-CHANGED] _onAuthChanged triggered. IsAuthenticated: ${authProvider.isAuthenticated}.',
    );
    if (authProvider.isAuthenticated) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-AUTH-CHANGED] User is authenticated. Calling fetchPairedMobileDevices.',
      );
      fetchPairedMobileDevices();
    } else {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-AUTH-CHANGED] User is NOT authenticated. Calling clearState.',
      );
      clearState();
    }
  }

  Future<void> fetchPairedMobileDevices() async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-FETCH-START] fetchPairedMobileDevices called.',
    );
    if (_isLoading) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-FETCH-ALREADY-LOADING] Already fetching. Aborting.',
      );
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-FETCH-SET-LOADING] Setting _isLoading to true and notifying listeners.',
    );
    notifyListeners();

    try {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-FETCH-REPO-CALL] Calling deviceRepository.getPairedMobileDevices().',
      );
      final devices = await deviceRepository.getPairedMobileDevices();
      _pairedMobileDevices = devices;
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-FETCH-REPO-SUCCESS] Fetched ${_pairedMobileDevices.length} mobile devices.',
      );

      if (_pairedMobileDevices.isEmpty && authProvider.isAuthenticated) {
        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-FETCH-NO-DEVICES] No paired devices found. Attempting to get a new pairing token.',
        );
        final token = await authRepository.getToken();
        final agentDeviceId = await authRepository.getDeviceId(
          'agent_device_id',
        );
        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-FETCH-TOKEN-CHECK] Retrieved token: ${token != null}, agentDeviceId: ${agentDeviceId != null}.',
        );
        if (token != null && agentDeviceId != null) {
          _pairingToken = await authRepository.initiatePairing(
            token: token,
            agentDeviceId: agentDeviceId,
            agentDeviceName:
                'My Windows Agent', // Note: This could be dynamic later
          );
          debugPrint(
            '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-FETCH-NEW-TOKEN] Got new pairing token: ${_pairingToken != null}.',
          );
        }
      } else {
        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-FETCH-HAS-DEVICES] Paired devices found. Setting pairingToken to null.',
        );
        _pairingToken = null;
      }
    } catch (e) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-FETCH-FAIL] Caught an exception: $e',
      );
      _errorMessage = 'Could not fetch devices: $e';
      _pairedMobileDevices = [];
      _pairingToken = null;
    } finally {
      _isLoading = false;
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-FETCH-FINALLY] Setting _isLoading to false and notifying listeners.',
      );
      notifyListeners();
    }
  }

  void unpairMobileDevice(int deviceId) async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-UNPAIR-START] unpairMobileDevice called for ID: $deviceId.',
    );
    _errorMessage = null;
    try {
      await deviceRepository.unpairMobileDevice(deviceId);
      _pairedMobileDevices.removeWhere((d) => d.id == deviceId);
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-UNPAIR-SUCCESS] Unpaired device. Remaining devices: ${_pairedMobileDevices.length}.',
      );

      if (_pairedMobileDevices.isEmpty) {
        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-UNPAIR-REFETCH] No devices left. Refetching to get a new pairing token.',
        );
        await fetchPairedMobileDevices();
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to unpair device: $e';
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-UNPAIR-FAIL] Unpairing failed: $e.',
      );
    } finally {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-UNPAIR-FINALLY] Notifying listeners.',
      );
      notifyListeners();
    }
  }

  void clearState() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-CLEAR] clearState called.',
    );
    _pairedMobileDevices = [];
    _pairingToken = null;
    _isLoading = false;
    _errorMessage = null;
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-CLEAR-NOTIFY] Notifying listeners after clearing state.',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-DEVPROV-DISPOSE] DeviceProvider disposed.',
    );
    authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}
