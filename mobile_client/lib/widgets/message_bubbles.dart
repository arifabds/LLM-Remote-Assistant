import 'package:flutter/material.dart';
import '../models/message_model.dart';

class StatusUpdateBubble extends StatelessWidget {
  final StatusUpdateMessage message;
  const StatusUpdateBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message.message,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class ExecutionResultBubble extends StatelessWidget {
  final ExecutionResultMessage message;
  const ExecutionResultBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isError = message.status == 'error';
    final bool isCancelled = message.status == 'cancelled';

    final Color bubbleColor = isError
        ? Colors.red.shade900.withValues(alpha: 0.5)
        : isCancelled
        ? Colors.orange.shade900.withValues(alpha: 0.5)
        : Colors.green.shade900.withValues(alpha: 0.5);

    final Color borderColor = isError
        ? Colors.red.shade400
        : isCancelled
        ? Colors.orange.shade400
        : Colors.green.shade400;

    final IconData icon = isError
        ? Icons.error_outline
        : isCancelled
        ? Icons.info_outline
        : Icons.check_circle_outline;

    final String title = isError
        ? 'Execution Failed'
        : isCancelled
        ? 'Action Cancelled'
        : 'Execution Successful';

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: borderColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: borderColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (message.output.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              message.output,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class UserCommandBubble extends StatelessWidget {
  final UserCommandMessage message;
  const UserCommandBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(top: 4, bottom: 4, left: 60, right: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade800,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          message.prompt,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class GenericMessageBubble extends StatelessWidget {
  final GenericMessage message;
  const GenericMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(message.rawJson),
    );
  }
}
