import 'package:flutter/material.dart';
import '../../models/messages/status_update_message.dart';

class StatusUpdateBubble extends StatelessWidget {
  final StatusUpdateMessage message;
  final bool isCompleted;

  const StatusUpdateBubble({
    super.key,
    required this.message,
    this.isCompleted = false,
  });

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
          isCompleted
              ? Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent.shade400,
                  size: 14,
                )
              : SizedBox(
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
