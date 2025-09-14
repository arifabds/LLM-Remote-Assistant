import 'execution_result_message.dart';
import 'generic_message.dart';
import 'status_update_message.dart';

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
