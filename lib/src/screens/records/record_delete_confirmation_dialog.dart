import 'package:flutter/material.dart';

Future<bool> showRecordDeleteConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  return shouldDelete ?? false;
}
