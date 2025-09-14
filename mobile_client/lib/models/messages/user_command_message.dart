import 'app_message.dart';

class UserCommandMessage extends AppMessage {
  final String prompt;
  UserCommandMessage(this.prompt)
    : super('{"type":"user_command", "prompt":"$prompt"}');
}
