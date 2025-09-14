import 'app_message.dart';

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
