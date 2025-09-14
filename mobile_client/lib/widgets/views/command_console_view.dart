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

    debugPrint(
      ' paranoid_log [5/5 | ConsoleView]: Building ListView. Command count: ${commandProvider.commandOrder.length}',
    );

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: commandProvider.commandOrder.length,
            itemBuilder: (ctx, i) {
              final commandId = commandProvider.commandOrder[i];
              final messages = commandProvider.messageGroups[commandId]!;

              debugPrint(
                ' paranoid_log [ItemBuilder | ConsoleView]: Building bubble for commandId $commandId with ${messages.length} messages.',
              );

              // --- DEĞİŞİKLİK BURADA ---
              // Flutter'a bu widget'ın benzersiz olduğunu ve yeniden
              // oluşturulması gerektiğini söylemek için bir ValueKey ekliyoruz.
              // commandId ve mesaj sayısı değiştiğinde, Flutter yeni bir
              // State nesnesi oluşturacak ve initState/didUpdateWidget doğru çalışacak.
              return CommandLifecycleBubble(
                key: ValueKey('${commandId}_${messages.length}'),
                messages: messages,
              );
              // --- DEĞİŞİKLİK SONU ---
            },
          ),
        ),
        CommandInputBar(onSendCommand: onSendCommand, isEnabled: isAgentOnline),
      ],
    );
  }
}
