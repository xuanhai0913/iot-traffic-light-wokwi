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
    this.enabled = true,
    super.key,
  });

  final String modeCode;
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final bool loading;
  final bool enabled;
  final Future<void> Function(String modeCode) onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 44,
        child: FilledButton.icon(
          onPressed:
              loading || active || !enabled ? null : () => onPressed(modeCode),
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
    required this.online,
    required this.isRunning,
    required this.onCommand,
    super.key,
  });

  final DashboardSnapshot snapshot;
  final String currentMode;
  final bool online;
  final bool Function(String key) isRunning;
  final Future<void> Function(String modeCode) onCommand;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.status;
    final activeColor = dominantSignalColor(status);
    final countdown =
        status.remainingSeconds >= 0 ? '${status.remainingSeconds}s' : '--';
    final allowPriority = currentMode != 'EMERGENCY';
    final commandBusy = const [
      'AUTO',
      'NIGHT',
      'EMERGENCY',
      'PRIORITY_NS',
      'PRIORITY_EW',
    ].any((mode) => isRunning('cmd:$mode'));
    final commandsEnabled = online && !commandBusy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    label: 'Chế độ',
                    value: _modeSummary(currentMode),
                    color: _modeColor(currentMode),
                  ),
                  const SizedBox(width: 8),
                  StatusStat(
                    label: 'Pha',
                    value: _phaseLabel(status.phaseCode),
                    color: _signalColor(activeColor),
                  ),
                  const SizedBox(width: 8),
                  StatusStat(
                    label: 'Còn lại',
                    value: countdown,
                    color: _signalColor(activeColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionLabel('Chế độ điều khiển'),
        Row(
          children: [
            MiniCommandButton(
              modeCode: 'AUTO',
              label: 'Tự động',
              icon: Icons.autorenew,
              color: AppColors.accent,
              active: currentMode == 'AUTO',
              loading: isRunning('cmd:AUTO'),
              enabled: commandsEnabled,
              onPressed: onCommand,
            ),
            const SizedBox(width: 8),
            MiniCommandButton(
              modeCode: 'NIGHT',
              label: 'Ban đêm',
              icon: Icons.nightlight_round,
              color: AppColors.warn,
              active: currentMode == 'NIGHT',
              loading: isRunning('cmd:NIGHT'),
              enabled: commandsEnabled,
              onPressed: onCommand,
            ),
            const SizedBox(width: 8),
            MiniCommandButton(
              modeCode: 'EMERGENCY',
              label: 'Dừng',
              icon: Icons.stop_rounded,
              color: AppColors.danger,
              active: currentMode == 'EMERGENCY',
              loading: isRunning('cmd:EMERGENCY'),
              enabled: commandsEnabled,
              onPressed: onCommand,
            ),
          ],
        ),
        const SectionLabel('Ưu tiên luồng'),
        Row(
          children: [
            MiniCommandButton(
              modeCode: 'PRIORITY_NS',
              label: 'Bắc-Nam',
              icon: Icons.swap_vert,
              color: AppColors.success,
              active: currentMode == 'PRIORITY_NS',
              loading: isRunning('cmd:PRIORITY_NS'),
              enabled: allowPriority && commandsEnabled,
              onPressed: onCommand,
            ),
            const SizedBox(width: 8),
            MiniCommandButton(
              modeCode: 'PRIORITY_EW',
              label: 'Đông-Tây',
              icon: Icons.swap_horiz,
              color: AppColors.success,
              active: currentMode == 'PRIORITY_EW',
              loading: isRunning('cmd:PRIORITY_EW'),
              enabled: allowPriority && commandsEnabled,
              onPressed: onCommand,
            ),
          ],
        ),
        if (!online) ...[
          const SizedBox(height: 10),
          const Text(
            'Kết nối lại API để gửi lệnh điều khiển.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.warn, fontSize: 12),
          ),
        ],
      ],
    );
  }

  String _colorVietnamese(String color) {
    return switch (color) {
      'GREEN' => 'Đèn xanh',
      'YELLOW' => 'Đèn vàng',
      'RED' => 'Đèn đỏ',
      _ => 'Đèn tắt',
    };
  }

  String _modeSummary(String modeCode) {
    return switch (modeCode) {
      'AUTO' => 'Tự động',
      'NIGHT' => 'Ban đêm',
      'PRIORITY_NS' => 'Ưu tiên NS',
      'PRIORITY_EW' => 'Ưu tiên EW',
      'EMERGENCY' => 'Khẩn cấp',
      '' => '--',
      _ => modeLabel(modeCode),
    };
  }

  String _phaseLabel(String phaseCode) {
    return phaseLabel(phaseCode);
  }

  Color _modeColor(String modeCode) {
    return switch (modeCode) {
      'AUTO' => AppColors.accent,
      'NIGHT' => AppColors.warn,
      'PRIORITY_NS' || 'PRIORITY_EW' => AppColors.success,
      'EMERGENCY' => AppColors.danger,
      _ => AppColors.foreground2,
    };
  }

  Color _signalColor(String color) {
    return switch (color) {
      'GREEN' => AppColors.success,
      'YELLOW' => AppColors.warn,
      'RED' => AppColors.danger,
      _ => AppColors.foreground2,
    };
  }
}

String dominantSignalColor(TrafficStatus status) {
  const priority = ['GREEN', 'YELLOW', 'RED'];
  for (final color in priority) {
    if (status.signals.any((signal) => signal.color == color)) {
      return color;
    }
  }
  return switch (status.phaseCode) {
    'NS_GREEN' || 'EW_GREEN' || 'NS_PRIORITY' || 'EW_PRIORITY' => 'GREEN',
    'NS_YELLOW' || 'EW_YELLOW' || 'YELLOW_BLINK' => 'YELLOW',
    'ALL_RED' => 'RED',
    _ => 'OFF',
  };
}
