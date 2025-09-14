import 'package:flutter/material.dart';
import '../../models/messages/execution_result_message.dart';
import '../../models/messages/generic_message.dart';
import '../../models/messages/status_update_message.dart';
import '../../models/messages/user_command_message.dart';
import '../../models/messages/app_message.dart';
import '../bubbles.dart';
import '../command_input_bar.dart';

class CommandConsoleView extends StatelessWidget {
  final List<AppMessage> messages;
  final ScrollController scrollController;
  final Function(String) onSendCommand;
  final bool isAgentOnline;

  const CommandConsoleView({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.onSendCommand,
    required this.isAgentOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: messages.length,
            itemBuilder: (ctx, i) {
              final message = messages[i];

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
                if (message.rawJson.contains('welcome')) {
                  return const SizedBox.shrink();
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      message.rawJson,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        CommandInputBar(onSendCommand: onSendCommand, isEnabled: isAgentOnline),
      ],
    );
  }
}
