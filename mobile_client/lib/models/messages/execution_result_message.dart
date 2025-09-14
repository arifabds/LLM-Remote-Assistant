import 'app_message.dart';

class ExecutionResultMessage extends AppMessage {
  final String status;
  final String output;

  ExecutionResultMessage({
    required this.status,
    required this.output,
    required String rawJson,
  }) : super(rawJson);

  factory ExecutionResultMessage.fromMap(
    String rawJson,
    Map<String, dynamic> map,
  ) {
    return ExecutionResultMessage(
      status: map['status'] ?? 'unknown',
      output: map['output'] ?? 'No output.',
      rawJson: rawJson,
    );
  }
}
