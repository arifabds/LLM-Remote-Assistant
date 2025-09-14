import 'package:flutter/material.dart';
import '../../models/messages/generic_message.dart';

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
