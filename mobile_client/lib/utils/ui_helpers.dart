import 'package:flutter/material.dart';
import '../providers/command_provider.dart';

Future<void> showConfirmationDialog(
  BuildContext context,
  CommandProvider provider,
) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: const Text('Confirmation Required'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(
                provider.pendingIntent ?? 'An action requires your approval.',
              ),
              const SizedBox(height: 10),
              Text(
                provider.pendingExplanation ??
                    'Please confirm if you want to proceed.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () {
              provider.sendConfirmationResponse(false);
              Navigator.of(ctx).pop();
            },
          ),
          FilledButton(
            child: const Text('APPROVE'),
            onPressed: () {
              provider.sendConfirmationResponse(true);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      );
    },
  );
}
