import 'package:flutter/material.dart';

Future<bool> showUnpairConfirmationDialog(
  BuildContext context,
  String deviceName,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm Unpair'),
      content: Text(
        'Are you sure you want to unpair "$deviceName"? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Unpair'),
        ),
      ],
    ),
  );
  return result ?? false;
}
