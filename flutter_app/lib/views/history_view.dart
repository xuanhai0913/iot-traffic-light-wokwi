import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../data/dashboard_snapshot.dart';
import '../widgets/atoms.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({required this.commands, required this.logs, super.key});

  final List<CommandEntry> commands;
  final List<TrafficLog> logs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Command history',
          child: commands.isEmpty
              ? const EmptyState(text: 'Chưa có command')
              : Column(
                  children: commands
                      .map((entry) => CommandTile(entry: entry))
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Device logs',
          child: logs.isEmpty
              ? const EmptyState(text: 'Chưa có log')
              : Column(
                  children: logs.map((log) => LogTile(log: log)).toList(),
                ),
        ),
      ],
    );
  }
}

