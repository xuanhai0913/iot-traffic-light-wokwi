import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../data/dashboard_snapshot.dart';
import '../widgets/atoms.dart';

const _kLogFilters = <_LogFilter>[
  _LogFilter('all', 'Tat ca'),
  _LogFilter('info', 'INFO'),
  _LogFilter('ok', 'OK'),
  _LogFilter('warn', 'WARN'),
  _LogFilter('err', 'ERROR'),
];


class DeviceLogsView extends StatefulWidget {
  const DeviceLogsView({required this.logs, super.key});

  final List<TrafficLog> logs;

  @override
  State<DeviceLogsView> createState() => _DeviceLogsViewState();
}


class _DeviceLogsViewState extends State<DeviceLogsView> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? widget.logs
        : widget.logs.where((l) => logLevel(l) == _filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          padding: const EdgeInsets.symmetric(
            horizontal: AppColors.space3,
            vertical: AppColors.space2,
          ),
          child: Row(
            children: [
              _FilterDropdown(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(width: AppColors.space2),
              Text(
                '${filtered.length} logs',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppColors.space2),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppColors.space5),
                  child: EmptyState(text: 'Chua co log'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => LogTile(log: filtered[i]),
                ),
        ),
      ],
    );
  }
}


class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppColors.space2),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: AppColors.surface,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.foreground2,
            size: 18,
          ),
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 12,
          ),
          items: _kLogFilters
              .map((f) => DropdownMenuItem<String>(
                    value: f.value,
                    child: Text(f.label),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}


class _LogFilter {
  const _LogFilter(this.value, this.label);

  final String value;
  final String label;
}