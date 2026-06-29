import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/colors.dart';

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}


class CommandResultDialog extends StatelessWidget {
  const CommandResultDialog({
    required this.command,
    required this.commandId,
    required this.modeCode,
    required this.source,
    required this.createdBy,
    required this.createdAt,
    required this.deviceStatus,
    this.isIOS = false,
    super.key,
  });

  final String command;
  final String commandId;
  final String modeCode;
  final String source;
  final String createdBy;
  final String createdAt;
  final String deviceStatus;
  final bool isIOS;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultRow(label: 'Command ID', value: commandId),
        _ResultRow(label: 'Mode', value: modeCode),
        _ResultRow(label: 'Source', value: source),
        _ResultRow(label: 'Created by', value: createdBy),
        _ResultRow(label: 'Created at', value: createdAt),
        _ResultRow(label: 'Device status', value: deviceStatus),
        const SizedBox(height: 8),
        const Text(
          'The MQTT bridge will publish this payload to the '
          'Wokwi device on the next tick.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
    if (isIOS) {
      return CupertinoAlertDialog(
        title: Text('Command accepted: $command'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: body,
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF1F7A5B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Command accepted: $command',
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: body,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}


enum DangerLevel {
  safe('Safe', Icons.check_circle_outline, Color(0xFF1F7A5B), 'No extra caution needed.'),
  risky('Risky', Icons.warning_amber_rounded, Color(0xFFB26A00),
      'One direction will be blocked from green.'),
  critical('Critical', Icons.dangerous_outlined, Color(0xFFC0392B),
      'All approaches will flash red until cleared by the operator.');

  const DangerLevel(this.label, this.icon, this.color, this.description);

  final String label;
  final IconData icon;
  final Color color;
  final String description;

  static DangerLevel forMode(String modeCode) {
    return switch (modeCode) {
      'EMERGENCY' => DangerLevel.critical,
      'PRIORITY_NS' || 'PRIORITY_EW' => DangerLevel.risky,
      _ => DangerLevel.safe,
    };
  }
}


class DangerousCommandDialog extends StatelessWidget {
  const DangerousCommandDialog({
    required this.modeCode,
    required this.danger,
    this.isIOS = false,
    super.key,
  });

  final String modeCode;
  final DangerLevel danger;
  final bool isIOS;

  String get _impact {
    return switch (modeCode) {
      'PRIORITY_NS' =>
        'North-South will get a forced green while East-West stays red.',
      'PRIORITY_EW' =>
        'East-West will get a forced green while North-South stays red.',
      'EMERGENCY' =>
        'Both directions will lock on flashing red. Traffic will stop '
            'until you switch back to AUTO or NIGHT.',
      _ => danger.description,
    };
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Risk level: ${danger.label}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: danger.color,
          ),
        ),
        const SizedBox(height: 12),
        Text(_impact),
        const SizedBox(height: 12),
        const Text(
          'The Wokwi device will receive the new mode on its next '
          'MQTT tick (~1 second).',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
    if (isIOS) {
      return CupertinoAlertDialog(
        title: Text('Confirm SET_$modeCode'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: content,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send anyway'),
          ),
        ],
      );
    }
    return AlertDialog(
      icon: Icon(danger.icon, color: danger.color, size: 32),
      title: Text('Confirm SET_$modeCode'),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: danger.color,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.send),
          label: const Text('Send anyway'),
        ),
      ],
    );
  }
}

