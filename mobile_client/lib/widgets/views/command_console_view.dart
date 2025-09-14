import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/command_provider.dart';
import '../bubbles.dart';
import '../command_input_bar.dart';

class CommandConsoleView extends StatelessWidget {
  final ScrollController scrollController;
  final Function(String) onSendCommand;
  final bool isAgentOnline;

  const CommandConsoleView({
    super.key,
    required this.scrollController,
    required this.onSendCommand,
    required this.isAgentOnline,
  });

  @override
  Widget build(BuildContext context) {
    final commandProvider = context.watch<CommandProvider>();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: commandProvider.commandOrder.length,
            itemBuilder: (ctx, i) {
              final commandId = commandProvider.commandOrder[i];
              final messages = commandProvider.messageGroups[commandId]!;

              return CommandLifecycleBubble(
                key: ValueKey('${commandId}_${messages.length}'),
                messages: messages,
              );
            },
          ),
        ),
        CommandInputBar(
          onSendCommand: onSendCommand,
          isEnabled: isAgentOnline,
          isSending: commandProvider.isSendingCommand,
        ),
      ],
    );
  }
}
