import 'package:flutter/material.dart';

class CommandInputBar extends StatefulWidget {
  final Function(String) onSendCommand;
  final bool isEnabled;

  const CommandInputBar({
    super.key,
    required this.onSendCommand,
    this.isEnabled = true,
  });

  @override
  State<CommandInputBar> createState() => _CommandInputBarState();
}

class _CommandInputBarState extends State<CommandInputBar> {
  final _textController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitCommand() {
    if (_isSending || !widget.isEnabled) return;

    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _isSending = true;
      });

      widget.onSendCommand(text);
      _textController.clear();

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEffectivelyEnabled = widget.isEnabled && !_isSending;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: isEffectivelyEnabled,
              decoration: InputDecoration(
                hintText: widget.isEnabled
                    ? 'Enter a command...'
                    : 'Agent is offline',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submitCommand(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: _isSending
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: isEffectivelyEnabled ? _submitCommand : null,
                  ),
          ),
        ],
      ),
    );
  }
}
