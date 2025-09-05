import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/command_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
