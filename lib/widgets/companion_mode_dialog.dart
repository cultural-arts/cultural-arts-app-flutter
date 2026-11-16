import 'package:flutter/material.dart';

import '../utils/companion_mode.dart';

Future<CompanionMode?> showCompanionModeDialog(
  BuildContext context, {
  CompanionMode? initialMode,
}) {
  return showDialog<CompanionMode>(
    context: context,
    builder: (context) => _CompanionModeDialog(initialMode: initialMode),
  );
}

class _CompanionModeDialog extends StatefulWidget {
  const _CompanionModeDialog({required this.initialMode});

  final CompanionMode? initialMode;

  @override
  State<_CompanionModeDialog> createState() => _CompanionModeDialogState();
}

class _CompanionModeDialogState extends State<_CompanionModeDialog> {
  late CompanionMode? selectedMode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialMode == null
          ? 'Choose your AI companion mode'
          : 'AI companion mode'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<CompanionMode>(
            groupValue: selectedMode,
            onChanged: (value) => setState(() => selectedMode = value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: CompanionMode.values
                  .map(
                    (mode) => RadioListTile<CompanionMode>(
                      contentPadding: EdgeInsets.zero,
                      value: mode,
                      title: Text(mode.title),
                      subtitle: Text(mode.description),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: selectedMode == null
              ? null
              : () => Navigator.pop(context, selectedMode),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
