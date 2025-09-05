import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/command_provider.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();

  Future<void> _navigateToScanner() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final qrCodeValue = await context.push<String>('/qr-scanner');

    if (qrCodeValue == null) return;

    if (!mounted) return;

    try {
      await _authService.pairDevice(
        pairingToken: qrCodeValue,
        deviceName: 'My Flutter Paired PC',
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Device paired successfully!'),
          backgroundColor: Colors.green,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final commandProvider = context.watch<CommandProvider>();
    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Command Center (Connected: ${commandProvider.isConnected})',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Pair a new device',
            onPressed: _navigateToScanner,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: commandProvider.consoleMessages.length,
              itemBuilder: (ctx, i) =>
                  ListTile(title: Text(commandProvider.consoleMessages[i])),
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
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendCommand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
