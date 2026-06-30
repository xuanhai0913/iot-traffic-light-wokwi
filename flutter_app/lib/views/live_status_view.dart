import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../data/dashboard_snapshot.dart';
import '../widgets/atoms.dart';
import '../widgets/traffic_lamps.dart';

class LiveStatusView extends StatelessWidget {
  const LiveStatusView({
    required this.snapshot,
    required this.lastSnapshotAt,
    required this.online,
    super.key,
  });

  final DashboardSnapshot snapshot;
  final DateTime? lastSnapshotAt;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.status;
    final activeApproaches = <String, bool>{
      for (final approach in snapshot.approaches)
        approach.code.toUpperCase(): approach.isActive,
    };
    final hasDeviceStatus = snapshot.deviceStatuses.isNotEmpty;
    final deviceOnline = snapshot.deviceStatuses.any(
      (device) =>
          text(device['connection_state'], '').toLowerCase() == 'online',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PulseDot(color: online ? AppColors.success : AppColors.warn),
                const SizedBox(width: 8),
                Text(
                  online ? 'Backend đang phản hồi' : 'Mất kết nối backend',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            _LiveBadge(
              text: online ? 'API online' : 'API ngoại tuyến',
              color: online ? AppColors.success : AppColors.warn,
            ),
            _LiveBadge(
              text: !hasDeviceStatus
                  ? 'Chưa có heartbeat'
                  : deviceOnline
                      ? 'Thiết bị online'
                      : 'Thiết bị offline',
              color: deviceOnline ? AppColors.success : AppColors.warn,
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.56,
          children: ['NORTH', 'EAST', 'SOUTH', 'WEST']
              .map((direction) => DirectionSignalCard(
                    direction: direction,
                    signal: _signalFor(status, direction),
                    latency: _latencyLabel(),
                    online: online,
                    enabled: activeApproaches[direction] ?? true,
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: Row(
            children: [
              StatusStat(label: 'Chu kỳ', value: modeLabel(status.modeCode)),
              const SizedBox(width: 8),
              StatusStat(
                label: 'Còn lại',
                value: status.remainingSeconds >= 0
                    ? '${status.remainingSeconds}s'
                    : '--',
              ),
              const SizedBox(width: 8),
              StatusStat(
                label: 'Pha',
                value: phaseLabel(status.phaseCode),
                color: DirectionSignalCard._phaseColor(status.phaseCode),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _latencyLabel() {
    final at = lastSnapshotAt;
    if (at == null) return 'Chưa có dữ liệu';
    final seconds = DateTime.now().difference(at).inSeconds;
    if (seconds <= 0) {
      return 'Vừa xong';
    }
    return '$seconds giây trước';
  }

  static SignalStatus _signalFor(TrafficStatus status, String direction) {
    return status.signals.firstWhere(
      (signal) => signal.approach.toUpperCase() == direction,
      orElse: () => SignalStatus(
        approach: direction,
        signal: '${direction}_MAIN',
        color: 'OFF',
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class DirectionSignalCard extends StatelessWidget {
  const DirectionSignalCard({
    required this.direction,
    required this.signal,
    required this.latency,
    required this.online,
    required this.enabled,
    super.key,
  });

  final String direction;
  final SignalStatus signal;
  final String latency;
  final bool online;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            _directionLabel(direction),
            style: const TextStyle(
              color: AppColors.foreground2,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Opacity(
            opacity: enabled ? 1 : 0.42,
            child: TrafficLampStack(activeColor: signal.color, large: false),
          ),
          const SizedBox(height: 6),
          Text(
            enabled ? _signalLabel(signal.color) : 'Tắt ở backend',
            style: TextStyle(
              color: enabled ? _signalColor(signal.color) : AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            enabled ? latency : 'Không xuất status',
            style: TextStyle(
              color: enabled
                  ? (online ? AppColors.success : AppColors.warn)
                  : AppColors.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _directionLabel(String value) {
    return switch (value) {
      'NORTH' => '↑ Bắc',
      'EAST' => '→ Đông',
      'SOUTH' => '↓ Nam',
      'WEST' => '← Tây',
      _ => value,
    };
  }

  String _signalLabel(String color) {
    return switch (color) {
      'GREEN' => 'Xanh',
      'YELLOW' => 'Vàng',
      'RED' => 'Đỏ',
      _ => 'Tắt',
    };
  }

  Color _signalColor(String color) {
    return switch (color) {
      'GREEN' => AppColors.success,
      'YELLOW' => AppColors.warn,
      'RED' => AppColors.danger,
      _ => AppColors.muted,
    };
  }

  static Color _phaseColor(String phaseCode) {
    return switch (phaseCode) {
      'NS_GREEN' ||
      'EW_GREEN' ||
      'NS_PRIORITY' ||
      'EW_PRIORITY' =>
        AppColors.success,
      'NS_YELLOW' || 'EW_YELLOW' || 'YELLOW_BLINK' => AppColors.warn,
      'ALL_RED' => AppColors.danger,
      _ => AppColors.foreground2,
    };
  }
}
