import 'package:flutter/material.dart';

import '../data/dashboard_snapshot.dart';
import '../widgets/atoms.dart';
import 'device_logs_view.dart';

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
          title: 'Lịch sử lệnh',
          child: commands.isEmpty
              ? const EmptyState(text: 'Chưa có lệnh')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: commands.length,
                  itemBuilder: (_, i) => CommandTile(entry: commands[i]),
                ),
        ),
        const SectionLabel('Nhật ký trạng thái'),
        DeviceLogsView(logs: logs),
      ],
    );
  }
}
