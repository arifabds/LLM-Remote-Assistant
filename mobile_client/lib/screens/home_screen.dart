import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/device_model.dart';
import '../providers/command_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/device_provider.dart';
import '../repositories/device_repository.dart';
import '../services/connection_status.dart';
import '../utils/ui_helpers.dart';
import '../widgets/views/agent_offline_view.dart';
import '../widgets/views/command_console_view.dart';
import '../widgets/views/pairing_prompt_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Stopwatch _logStopwatch = Stopwatch()..start();
  final ScrollController _scrollController = ScrollController();
  final DeviceRepository _deviceRepository = DeviceRepository();

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-INIT] HomeScreen initState called.',
    );
  }

  @override
  void dispose() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-DISPOSE] HomeScreen dispose called.',
    );
    _scrollController.dispose();
    super.dispose();
  }

  // NOT: Bu fonksiyon artık doğrudan kullanılmıyor, DevicesScreen'e taşındı.
  // Ancak referans ve olası geri dönüşler için loglu haliyle bırakıyorum.
  Future<void> _navigateToScanner() async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-NAV-SCANNER] _navigateToScanner called.',
    );
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final qrCodeValue = await context.push<String>('/qr-scanner');
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-NAV-SCANNER] QR scanner returned value: $qrCodeValue',
    );

    if (qrCodeValue == null || !mounted) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-NAV-SCANNER] QR code is null or screen is not mounted. Aborting.',
      );
      return;
    }
    try {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-NAV-SCANNER] Calling pairDevice repository method.',
      );
      await _deviceRepository.pairDevice(
        pairingToken: qrCodeValue,
        deviceName: 'My Flutter Mobile',
      );
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-NAV-SCANNER] Pairing successful. Showing SnackBar.',
      );
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Device paired successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-NAV-SCANNER] Calling deviceProvider.fetchDevices().',
      );
      await deviceProvider.fetchDevices();
    } catch (e) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-NAV-SCANNER] Pairing failed with exception: ${e.toString()}. Showing SnackBar.',
      );
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Pairing failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendCommand(String commandText) {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-SEND-CMD] _sendCommand called with text: "$commandText"',
    );
    Provider.of<CommandProvider>(
      context,
      listen: false,
    ).sendCommand(commandText);
  }

  Widget _buildBody(
    ConnectionProvider connectionProvider,
    DeviceProvider deviceProvider,
  ) {
    final hasPairedAgent = deviceProvider.devices.any(
      (d) => d.clientType == ClientType.AGENT,
    );

    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-BUILD-BODY] Building body with state: DeviceProvider isLoading: ${deviceProvider.isLoading}, hasPairedAgent: $hasPairedAgent. ConnectionProvider isAgentOnline: ${connectionProvider.isAgentOnline}.',
    );

    if (deviceProvider.isLoading && deviceProvider.devices.isEmpty) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-BUILD-BODY-DECISION] -> Showing CircularProgressIndicator.',
      );
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasPairedAgent) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-BUILD-BODY-DECISION] -> Showing PairingPromptView.',
      );
      return PairingPromptView(onPairDevice: _navigateToScanner);
    }

    if (!connectionProvider.isAgentOnline) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-BUILD-BODY-DECISION] -> Showing AgentOfflineView.',
      );
      return AgentOfflineView(onRefresh: () => deviceProvider.fetchDevices());
    }

    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-BUILD-BODY-DECISION] -> Showing CommandConsoleView.',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return CommandConsoleView(
      scrollController: _scrollController,
      onSendCommand: _sendCommand,
      isAgentOnline: connectionProvider.isAgentOnline,
    );
  }

  Widget _buildConnectionStatusIndicator(ConnectionStatus status) {
    IconData icon;
    Color color;
    String text;
    switch (status) {
      case ConnectionStatus.online:
        icon = Icons.circle;
        color = Colors.greenAccent;
        text = 'Online';
        break;
      case ConnectionStatus.offline:
        icon = Icons.circle;
        color = Colors.redAccent;
        text = 'Offline';
        break;
      case ConnectionStatus.connecting:
        icon = Icons.circle;
        color = Colors.orangeAccent;
        text = 'Connecting...';
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-BUILD] HomeScreen build method called.',
    );
    return Consumer3<CommandProvider, DeviceProvider, ConnectionProvider>(
      builder: (ctx, commandProvider, deviceProvider, connectionProvider, child) {
        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-CONSUMER-BUILD] Consumer3 builder triggered.',
        );
        if (commandProvider.isConfirmationPending) {
          debugPrint(
            '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-CONFIRMATION-PENDING] Confirmation is pending. Scheduling dialog display.',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ModalRoute.of(context)?.isCurrent == true) {
              debugPrint(
                '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-CONFIRMATION-SHOW] Showing confirmation dialog now.',
              );
              showConfirmationDialog(context, commandProvider);
            } else {
              debugPrint(
                '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-CONFIRMATION-SKIP] Route is not current. Skipping dialog display.',
              );
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: _buildConnectionStatusIndicator(
              connectionProvider.connectionStatus,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.devices),
                tooltip: 'Manage Devices',
                onPressed: () {
                  debugPrint(
                    '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-HOME-ACTION] Navigating to /devices.',
                  );
                  context.push('/devices');
                },
              ),
            ],
          ),
          body: _buildBody(connectionProvider, deviceProvider),
        );
      },
    );
  }
}
