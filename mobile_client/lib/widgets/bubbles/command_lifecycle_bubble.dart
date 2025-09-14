import 'package:flutter/material.dart';
import '../../models/messages/app_message.dart';
import '../../models/messages/execution_result_message.dart';
import '../../models/messages/status_update_message.dart';
import '../../models/messages/user_command_message.dart';
import 'execution_result_bubble.dart';
import 'status_update_bubble.dart';
import 'user_command_bubble.dart';

class CommandLifecycleBubble extends StatefulWidget {
  final List<AppMessage> messages;

  const CommandLifecycleBubble({super.key, required this.messages});

  @override
  State<CommandLifecycleBubble> createState() => _CommandLifecycleBubbleState();
}

class _CommandLifecycleBubbleState extends State<CommandLifecycleBubble> {
  late bool _isInitiallyExpanded;
  UserCommandMessage? _userCommand;
  List<StatusUpdateMessage> _statusUpdates = [];
  ExecutionResultMessage? _executionResult;

  @override
  void initState() {
    super.initState();
    _analyzeMessages();
    _isInitiallyExpanded = _executionResult == null;
  }

  @override
  void didUpdateWidget(covariant CommandLifecycleBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      setState(() {
        _analyzeMessages();
        if (_executionResult != null) {
          _isInitiallyExpanded = false;
        }
      });
    }
  }

  void _analyzeMessages() {
    _statusUpdates = [];
    _executionResult = null;
    _userCommand = null;

    for (var msg in widget.messages) {
      if (msg is UserCommandMessage) {
        _userCommand = msg;
      } else if (msg is StatusUpdateMessage) {
        _statusUpdates.add(msg);
      } else if (msg is ExecutionResultMessage) {
        _executionResult = msg;
      }
    }
  }

  Widget _buildCurrentStatus() {
    if (_executionResult != null) {
      return ExecutionResultBubble(message: _executionResult!);
    }
    if (_statusUpdates.isNotEmpty) {
      return StatusUpdateBubble(message: _statusUpdates.last);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (_userCommand == null) {
      return const SizedBox.shrink();
    }

    final bool isCompleted = _executionResult != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey(
          '${widget.messages.first.rawJson}_${widget.messages.length}',
        ),
        initiallyExpanded: _isInitiallyExpanded,
        tilePadding: EdgeInsets.zero,
        title: UserCommandBubble(message: _userCommand!),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 4.0),
          child: _buildCurrentStatus(),
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 8.0,
        ).copyWith(bottom: 8.0),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: _statusUpdates.map((update) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: StatusUpdateBubble(
              message: update,
              isCompleted: isCompleted,
            ),
          );
        }).toList(),
      ),
    );
  }
}
