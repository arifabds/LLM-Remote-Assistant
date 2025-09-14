import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/device_model.dart';
import '../providers/command_provider.dart';
import '../providers/device_provider.dart';
import '../services/device_service.dart';
import '../services/connection_status.dart';
import '../widgets/views/agent_offline_view.dart';
import '../widgets/views/command_console_view.dart';
import '../widgets/views/pairing_prompt_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _navigateToScanner() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final qrCodeValue = await context.push<String>('/qr-scanner');
    if (qrCodeValue == null || !mounted) return;
    try {
      await DeviceService().pairDevice(
        pairingToken: qrCodeValue,
        deviceName: 'My Flutter Mobile',
      );
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Device paired successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      await deviceProvider.fetchDevices();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Pairing failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendCommand(String commandText) {
    Provider.of<CommandProvider>(
      context,
      listen: false,
    ).sendCommand(commandText);
  }

  void _showConfirmationDialog(CommandProvider provider) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation Required'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(
                provider.pendingIntent ?? 'An action requires your approval.',
              ),
              const SizedBox(height: 10),
              Text(
                provider.pendingExplanation ??
                    'Please confirm if you want to proceed.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () {
              provider.sendConfirmationResponse(false);
              Navigator.of(ctx).pop();
            },
          ),
          FilledButton(
            child: const Text('APPROVE'),
            onPressed: () {
              provider.sendConfirmationResponse(true);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    CommandProvider commandProvider,
    DeviceProvider deviceProvider,
  ) {
    if (deviceProvider.isLoading && deviceProvider.devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasPairedAgent = deviceProvider.devices.any(
      (d) => d.clientType == ClientType.AGENT,
    );
    if (!hasPairedAgent) {
      return PairingPromptView(onPairDevice: _navigateToScanner);
    }

    if (!commandProvider.isAgentOnline) {
      return AgentOfflineView(onRefresh: () => deviceProvider.fetchDevices());
    }

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
      isAgentOnline: commandProvider.isAgentOnline,
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
    return Consumer2<CommandProvider, DeviceProvider>(
      builder: (ctx, commandProvider, deviceProvider, child) {
        if (commandProvider.isConfirmationPending) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showConfirmationDialog(commandProvider);
          });
        }
        return Scaffold(
          appBar: AppBar(
            title: _buildConnectionStatusIndicator(
              commandProvider.connectionStatus,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.devices),
                tooltip: 'Manage Devices',
                onPressed: () => context.push('/devices'),
              ),
              if (!deviceProvider.devices.any(
                (d) => d.clientType == ClientType.AGENT,
              ))
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Pair a new device',
                  onPressed: _navigateToScanner,
                ),
            ],
          ),
          body: _buildBody(commandProvider, deviceProvider),
        );
      },
    );
  }
}
