import 'package:flutter/material.dart';
import '../../models/messages/execution_result_message.dart';

class ExecutionResultBubble extends StatelessWidget {
  final ExecutionResultMessage message;
  const ExecutionResultBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isError = message.status == 'error';
    final bool isCancelled = message.status == 'cancelled';

    final Color bubbleColor = isError
        ? Colors.red.shade900.withAlpha(128)
        : isCancelled
        ? Colors.orange.shade900.withAlpha(128)
        : Colors.green.shade900.withAlpha(128);

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
