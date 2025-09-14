import 'package:flutter/material.dart';
import '../../models/messages/user_command_message.dart';

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
