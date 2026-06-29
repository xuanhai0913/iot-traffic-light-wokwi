import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../data/dashboard_snapshot.dart';
import '../widgets/atoms.dart';
import '../widgets/traffic_lamps.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({required this.snapshot, super.key});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridCards(
          cards: [
            MetricCard(label: 'Mode', value: modeLabel(status.modeCode)),
            MetricCard(label: 'Phase', value: status.phaseCode),
            MetricCard(
                label: 'Countdown',
                value: status.remainingSeconds >= 0
                    ? '${status.remainingSeconds}s'
                    : '--'),
            MetricCard(
                label: 'Devices', value: '${snapshot.deviceStatuses.length}'),
          ],
        ),
        const SizedBox(height: 12),
        SignalBoard(signals: status.signals),
        const SizedBox(height: 12),
        PhasePlanCard(phasePlans: snapshot.phasePlans),
      ],
    );
  }
}


class SignalBoard extends StatelessWidget {
  const SignalBoard({required this.signals, super.key});

  final List<SignalStatus> signals;

  @override
  Widget build(BuildContext context) {
    final byApproach = {for (final signal in signals) signal.approach: signal};
    return SectionCard(
      title: 'Intersection signals',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 4 : 2;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 144,
            children: ['NORTH', 'SOUTH', 'EAST', 'WEST'].map((approach) {
              return SignalCard(
                signal: byApproach[approach] ??
                    SignalStatus(
                      approach: approach,
                      signal: '${approach}_MAIN',
                      color: 'OFF',
                    ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}


class SignalCard extends StatelessWidget {
  const SignalCard({required this.signal, super.key});

  final SignalStatus signal;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDE3DC)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(signal.approach,
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Row(
              children: [
                Lamp(color: 'RED', active: signal.color == 'RED'),
                const SizedBox(width: 8),
                Lamp(color: 'YELLOW', active: signal.color == 'YELLOW'),
                const SizedBox(width: 8),
                Lamp(color: 'GREEN', active: signal.color == 'GREEN'),
              ],
            ),
            const SizedBox(height: 10),
            Text(signal.color, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}


class Lamp extends StatelessWidget {
  const Lamp({required this.color, required this.active, super.key});

  final String color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final base = switch (color) {
      'RED' => Colors.red,
      'YELLOW' => Colors.amber,
      'GREEN' => Colors.green,
      _ => Colors.grey,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? base : base.withValues(alpha: 0.18),
        border: Border.all(color: base.withValues(alpha: 0.55)),
      ),
    );
  }
}


class ControlButton extends StatelessWidget {
  const ControlButton({
    required this.modeCode,
    required this.label,
    required this.icon,
    required this.active,
    required this.loading,
    required this.onPressed,
    this.danger = false,
    super.key,
  });

  final String modeCode;
  final String label;
  final IconData icon;
  final bool active;
  final bool loading;
  final bool danger;
  final Future<void> Function(String modeCode) onPressed;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: active ? color : color.withValues(alpha: 0.72),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: loading ? null : () => onPressed(modeCode),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );
  }
}


class PhasePlanCard extends StatelessWidget {
  const PhasePlanCard({required this.phasePlans, super.key});

  final List<PhasePlan> phasePlans;

  @override
  Widget build(BuildContext context) {
    final activePlans = phasePlans.where((plan) => plan.isActive).toList();
    final active = activePlans.isNotEmpty
        ? activePlans.first
        : (phasePlans.isEmpty ? null : phasePlans.first);
    return SectionCard(
      title: 'Active phase plan',
      child: active == null
          ? const EmptyState(text: 'Chưa có phase plan')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(active.name,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...active.steps.map((step) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(step.code)),
                          Text('${step.durationSeconds}s'),
                        ],
                      ),
                    )),
              ],
            ),
    );
  }
}


class GridCards extends StatelessWidget {
  const GridCards({required this.cards, super.key});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 104,
          children: cards,
        );
      },
    );
  }
}


class MetricCard extends StatelessWidget {
  const MetricCard({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}


class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge(
      {required this.online, required this.loading, super.key});

  final bool online;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: loading ? 'Loading' : (online ? 'C# API connected' : 'Offline'),
      child: Icon(
        loading ? Icons.sync : (online ? Icons.cloud_done : Icons.cloud_off),
        color: online ? Colors.green : Colors.orange,
      ),
    );
  }
}

