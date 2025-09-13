import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/device_model.dart';
import '../providers/command_provider.dart';
import '../providers/device_provider.dart';
import '../services/device_service.dart';
import '../models/message_model.dart';
import '../widgets/message_bubbles.dart';
import '../services/connection_status.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DeviceService _deviceService = DeviceService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DeviceProvider>(
        context,
        listen: false,
      ).fetchDevices(isManualRefresh: true);
    });
  }

  Future<void> _navigateToScanner() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final qrCodeValue = await context.push<String>('/qr-scanner');

    if (qrCodeValue == null) return;

    if (!mounted) return;

    try {
      await _deviceService.pairDevice(
        pairingToken: qrCodeValue,
        deviceName: 'My Flutter Mobile',
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Device paired successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) {
        await Provider.of<DeviceProvider>(
          context,
          listen: false,
        ).fetchDevices();
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Pairing failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendCommand() {
    if (_commandController.text.trim().isEmpty) return;
    final commandProvider = Provider.of<CommandProvider>(
      context,
      listen: false,
    );
    commandProvider.sendCommand(_commandController.text.trim());
    _commandController.clear();
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Approval sent. Processing command...'),
                ),
              );
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
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
        text = 'Offline - Reconnecting...';
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

  Widget _buildBody(
    CommandProvider commandProvider,
    DeviceProvider deviceProvider,
  ) {
    if (deviceProvider.isLoading && deviceProvider.devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (deviceProvider.devices
        .where((d) => d.clientType == ClientType.AGENT)
        .isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.computer_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'No PC Agent Paired',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Please pair a PC agent to start sending commands.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code to Pair'),
                onPressed: _navigateToScanner,
              ),
            ],
          ),
        ),
      );
    }
    if (!deviceProvider.hasOnlineAgent) {
      if (deviceProvider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.signal_wifi_off_outlined,
                size: 80,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                'Agent is Offline',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Please make sure your paired PC agent is running and connected to the internet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              IconButton(
                icon: const Icon(Icons.refresh),
                iconSize: 40,
                tooltip: 'Refresh Status',
                onPressed: () =>
                    deviceProvider.fetchDevices(isManualRefresh: true),
              ),
            ],
          ),
        ),
      );
    }
    _scrollToBottom();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: commandProvider.messages.length,
            itemBuilder: (ctx, i) {
              final message = commandProvider.messages[i];

              if (message is UserCommandMessage) {
                return UserCommandBubble(message: message);
              }
              if (message is StatusUpdateMessage) {
                return StatusUpdateBubble(message: message);
              }
              if (message is ExecutionResultMessage) {
                return ExecutionResultBubble(message: message);
              }
              if (message is GenericMessage) {
                if (message.rawJson.startsWith('Connecting') ||
                    message.rawJson.startsWith('Disconnected') ||
                    message.rawJson.contains('back online')) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        message.rawJson,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
              return Text(message.rawJson);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commandController,
                  decoration: const InputDecoration(
                    hintText: 'Enter a command...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _sendCommand(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send),
                onPressed: _sendCommand,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
