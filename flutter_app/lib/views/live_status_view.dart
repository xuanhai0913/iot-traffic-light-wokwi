import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../data/dashboard_snapshot.dart';
import '../widgets/atoms.dart';
import '../widgets/traffic_lamps.dart';

class LiveStatusView extends StatelessWidget {
  const LiveStatusView({
    required this.snapshot,
    required this.lastSnapshotAt,
    super.key,
  });

  final DashboardSnapshot snapshot;
  final DateTime? lastSnapshotAt;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            PulseDot(color: AppColors.success),
            SizedBox(width: 8),
            Text('Đang hoạt động',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            _LiveBadge(text: '● MQTT'),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
          children: ['NORTH', 'EAST', 'SOUTH', 'WEST']
              .map((direction) => DirectionSignalCard(
                    direction: direction,
                    signal: _signalFor(status, direction),
                    latency: _latencyLabel(),
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
                value:
                    status.remainingSeconds >= 0 ? '${status.remainingSeconds}s' : '--',
              ),
              const SizedBox(width: 8),
              const StatusStat(
                label: 'Nhiệt',
                value: '—',
                color: AppColors.foreground2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _latencyLabel() {
    final at = lastSnapshotAt;
    if (at == null) return '—';
    final seconds = DateTime.now().difference(at).inSeconds;
    return '● ${seconds}s ago';
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
  const _LiveBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.success,
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
    super.key,
  });

  final String direction;
  final SignalStatus signal;
  final String latency;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.all(14),
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
          const SizedBox(height: 10),
          TrafficLampStack(activeColor: signal.color, large: false),
          const SizedBox(height: 8),
          Text(
            signal.color,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            latency,
            style: const TextStyle(color: AppColors.success, fontSize: 12),
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
}

