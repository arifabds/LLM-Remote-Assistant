abstract class AppMessage {
  final String rawJson;
  AppMessage(this.rawJson);

  factory AppMessage.fromJson(String jsonString, Map<String, dynamic> json) {
    switch (json['type']) {
      case 'status_update':
        return StatusUpdateMessage.fromMap(jsonString, json);
      case 'execution_result':
        return ExecutionResultMessage.fromMap(jsonString, json);
      default:
        return GenericMessage(jsonString);
    }
  }
}

class GenericMessage extends AppMessage {
  GenericMessage(super.rawJson);
}

class StatusUpdateMessage extends AppMessage {
  final String stage;
  final String message;

  StatusUpdateMessage({
    required this.stage,
    required this.message,
    required String rawJson,
  }) : super(rawJson);

  factory StatusUpdateMessage.fromMap(
    String rawJson,
    Map<String, dynamic> map,
  ) {
    return StatusUpdateMessage(
      stage: map['stage'] ?? 'unknown',
      message: map['message'] ?? '...',
      rawJson: rawJson,
    );
  }
}

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

class UserCommandMessage extends AppMessage {
  final String prompt;
  UserCommandMessage(this.prompt)
    : super('{"type":"user_command", "prompt":"$prompt"}');
}
