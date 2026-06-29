import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../data/dashboard_snapshot.dart';
import '../widgets/atoms.dart';
import '../widgets/traffic_lamps.dart';

class MiniCommandButton extends StatelessWidget {
  const MiniCommandButton({
    required this.modeCode,
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.loading,
    required this.onPressed,
    super.key,
  });

  final String modeCode;
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final bool loading;
  final Future<void> Function(String modeCode) onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 44,
        child: FilledButton.icon(
          onPressed: loading ? null : () => onPressed(modeCode),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            backgroundColor:
                active ? color : AppColors.glass.withValues(alpha: 0.9),
            foregroundColor: active ? Colors.white : AppColors.foreground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: active ? color : AppColors.glassBorder,
              ),
            ),
          ),
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 16),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}


class ControlView extends StatelessWidget {
  const ControlView({
    required this.snapshot,
    required this.currentMode,
    required this.isRunning,
    required this.onCommand,
    super.key,
  });

  final DashboardSnapshot snapshot;
  final String currentMode;
  final bool Function(String key) isRunning;
  final Future<void> Function(String modeCode) onCommand;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.status;
    final activeColor = _activeColor(status);
    final countdown =
        status.remainingSeconds >= 0 ? '${status.remainingSeconds}s' : '--';
    final isCycle = currentMode == 'AUTO';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ModeChip(
              label: 'Manual',
              active: !isCycle,
              onTap: currentMode == 'AUTO'
                  ? () => onCommand('NIGHT')
                  : () {},
            ),
            const SizedBox(width: 8),
            ModeChip(
              label: 'Auto Cycle',
              active: isCycle,
              onTap: () => onCommand('AUTO'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassPanel(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
          child: Column(
            children: [
              TrafficLampStack(activeColor: activeColor),
              const SizedBox(height: 12),
              Text(
                '${_colorVietnamese(activeColor)} · $countdown',
                style: const TextStyle(
                  color: AppColors.foreground2,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  StatusStat(
                    label: 'Trạng thái',
                    value: currentMode == 'EMERGENCY' ? 'Khẩn cấp' : 'Đang bật',
                    color: currentMode == 'EMERGENCY'
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  StatusStat(
                    label: 'Chu kỳ',
                    value: modeLabel(currentMode),
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  const StatusStat(
                    label: 'Nhiệt độ',
                    value: '—',
                    color: AppColors.foreground2,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            MiniCommandButton(
              modeCode: 'AUTO',
              label: 'Auto',
              icon: Icons.autorenew,
              color: AppColors.accent,
              active: currentMode == 'AUTO',
              loading: isRunning('cmd:AUTO'),
              onPressed: onCommand,
            ),
            const SizedBox(width: 8),
            MiniCommandButton(
              modeCode: 'NIGHT',
              label: 'Night',
              icon: Icons.nightlight_round,
              color: AppColors.warn,
              active: currentMode == 'NIGHT',
              loading: isRunning('cmd:NIGHT'),
              onPressed: onCommand,
            ),
            const SizedBox(width: 8),
            MiniCommandButton(
              modeCode: 'EMERGENCY',
              label: 'Stop',
              icon: Icons.stop_rounded,
              color: AppColors.danger,
              active: currentMode == 'EMERGENCY',
              loading: isRunning('cmd:EMERGENCY'),
              onPressed: onCommand,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            MiniCommandButton(
              modeCode: 'PRIORITY_NS',
              label: 'NS',
              icon: Icons.swap_vert,
              color: AppColors.success,
              active: currentMode == 'PRIORITY_NS',
              loading: isRunning('cmd:PRIORITY_NS'),
              onPressed: onCommand,
            ),
            const SizedBox(width: 8),
            MiniCommandButton(
              modeCode: 'PRIORITY_EW',
              label: 'EW',
              icon: Icons.swap_horiz,
              color: AppColors.success,
              active: currentMode == 'PRIORITY_EW',
              loading: isRunning('cmd:PRIORITY_EW'),
              onPressed: onCommand,
            ),
          ],
        ),
      ],
    );
  }

  String _activeColor(TrafficStatus status) {
    if (status.signals.isNotEmpty) {
      final active = status.signals.firstWhere(
        (signal) => signal.color != 'OFF',
        orElse: () => status.signals.first,
      );
      return active.color;
    }
    return switch (status.phaseCode) {
      'NS_GREEN' || 'EW_GREEN' => 'GREEN',
      'NS_YELLOW' || 'EW_YELLOW' => 'YELLOW',
      _ => 'RED',
    };
  }

  String _colorVietnamese(String color) {
    return switch (color) {
      'GREEN' => 'Đèn xanh',
      'YELLOW' => 'Đèn vàng',
      'RED' => 'Đèn đỏ',
      _ => 'Đèn tắt',
    };
  }
}

