import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../data/dashboard_snapshot.dart';
import '../widgets/atoms.dart';

class ManageView extends StatefulWidget {
  const ManageView({
    required this.phasePlans,
    required this.approaches,
    required this.isRunning,
    required this.onUpdatePlan,
    required this.onActivatePlan,
    required this.onUpdateApproach,
    super.key,
  });

  final List<PhasePlan> phasePlans;
  final List<Approach> approaches;
  final bool Function(String key) isRunning;
  final Future<void> Function(
      PhasePlan plan, int greenSeconds, int yellowSeconds) onUpdatePlan;
  final Future<void> Function(PhasePlan plan) onActivatePlan;
  final Future<void> Function(Approach approach, bool isActive)
      onUpdateApproach;

  @override
  State<ManageView> createState() => _ManageViewState();
}


class _ManageViewState extends State<ManageView> {
  @override
  Widget build(BuildContext context) {
    final activePlan = widget.phasePlans.where((plan) => plan.isActive).isEmpty
        ? (widget.phasePlans.isEmpty ? null : widget.phasePlans.first)
        : widget.phasePlans.firstWhere((plan) => plan.isActive);
    final green = activePlan?.greenSeconds ?? 25;
    final yellow = activePlan?.yellowSeconds ?? 5;
    final red = green + yellow + 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bật Auto Cycle',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('Đèn tự động chuyển theo chu kỳ',
                        style:
                            TextStyle(color: AppColors.foreground2, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: activePlan != null,
                activeColor: AppColors.success,
                onChanged: activePlan == null
                    ? null
                    : (_) => widget.onActivatePlan(activePlan),
              ),
            ],
          ),
        ),
        const SectionLabel('Thời gian chu kỳ (giây)'),
        TimingRow(
          color: AppColors.danger,
          label: 'Đèn đỏ',
          value: red,
          onMinus: activePlan == null
              ? null
              : () => widget.onUpdatePlan(activePlan, green, yellow),
          onPlus: activePlan == null
              ? null
              : () => widget.onUpdatePlan(activePlan, green + 5, yellow),
        ),
        const SizedBox(height: 6),
        TimingRow(
          color: AppColors.warn,
          label: 'Đèn vàng',
          value: yellow,
          onMinus: activePlan == null
              ? null
              : () => widget.onUpdatePlan(activePlan, green, yellow - 1),
          onPlus: activePlan == null
              ? null
              : () => widget.onUpdatePlan(activePlan, green, yellow + 1),
        ),
        const SizedBox(height: 6),
        TimingRow(
          color: AppColors.success,
          label: 'Đèn xanh',
          value: green,
          onMinus: activePlan == null
              ? null
              : () => widget.onUpdatePlan(activePlan, green - 5, yellow),
          onPlus: activePlan == null
              ? null
              : () => widget.onUpdatePlan(activePlan, green + 5, yellow),
        ),
        const SectionLabel('Lịch trình theo giờ'),
        const ScheduleCard(
          time: '06:00',
          period: 'Sáng',
          name: 'Giờ cao điểm sáng',
          subtitle: '45s chu kỳ',
          enabled: true,
        ),
        const SizedBox(height: 6),
        const ScheduleCard(
          time: '11:30',
          period: 'Trưa',
          name: 'Giờ thấp điểm',
          subtitle: '20s chu kỳ',
          enabled: false,
        ),
        const SizedBox(height: 6),
        const ScheduleCard(
          time: '17:00',
          period: 'Chiều',
          name: 'Giờ cao điểm chiều',
          subtitle: '50s chu kỳ',
          enabled: true,
        ),
        if (widget.approaches.isNotEmpty) ...[
          const SectionLabel('Luồng đường'),
          RoadsView(
            approaches: widget.approaches,
            isRunning: widget.isRunning,
            onUpdate: widget.onUpdateApproach,
          ),
        ],
      ],
    );
  }
}


class RoundIconButton extends StatelessWidget {
  const RoundIconButton({required this.icon, required this.onPressed, super.key});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: IconButton.filled(
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface2,
          foregroundColor: AppColors.foreground,
          disabledBackgroundColor: AppColors.surface,
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}


class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    required this.time,
    required this.period,
    required this.name,
    required this.subtitle,
    required this.enabled,
    super.key,
  });

  final String time;
  final String period;
  final String name;
  final String subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 12,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Column(
              children: [
                Text(time,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                Text(period.toUpperCase(),
                    style:
                        const TextStyle(color: AppColors.foreground2, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: AppColors.foreground2, fontSize: 12)),
              ],
            ),
          ),
          Switch(value: enabled, activeColor: AppColors.success, onChanged: (_) {}),
        ],
      ),
    );
  }
}


class PhasePlanEditor extends StatelessWidget {
  const PhasePlanEditor({
    required this.phasePlans,
    required this.isRunning,
    required this.onUpdate,
    required this.onActivate,
    super.key,
  });

  final List<PhasePlan> phasePlans;
  final bool Function(String key) isRunning;
  final Future<void> Function(
      PhasePlan plan, int greenSeconds, int yellowSeconds) onUpdate;
  final Future<void> Function(PhasePlan plan) onActivate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Phase plan configuration',
      child: phasePlans.isEmpty
          ? const EmptyState(text: 'Chưa có phase plan')
          : Column(
              children: phasePlans
                  .map(
                    (plan) => PhasePlanEditorTile(
                      plan: plan,
                      isRunning: isRunning,
                      onUpdate: onUpdate,
                      onActivate: onActivate,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}


class PhasePlanEditorTile extends StatefulWidget {
  const PhasePlanEditorTile({
    required this.plan,
    required this.isRunning,
    required this.onUpdate,
    required this.onActivate,
    super.key,
  });

  final PhasePlan plan;
  final bool Function(String key) isRunning;
  final Future<void> Function(
      PhasePlan plan, int greenSeconds, int yellowSeconds) onUpdate;
  final Future<void> Function(PhasePlan plan) onActivate;

  @override
  State<PhasePlanEditorTile> createState() => _PhasePlanEditorTileState();
}


class _PhasePlanEditorTileState extends State<PhasePlanEditorTile> {
  late final TextEditingController greenController;
  late final TextEditingController yellowController;

  @override
  void initState() {
    super.initState();
    greenController =
        TextEditingController(text: widget.plan.greenSeconds.toString());
    yellowController =
        TextEditingController(text: widget.plan.yellowSeconds.toString());
  }

  @override
  void didUpdateWidget(covariant PhasePlanEditorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.greenSeconds != widget.plan.greenSeconds) {
      greenController.text = widget.plan.greenSeconds.toString();
    }
    if (oldWidget.plan.yellowSeconds != widget.plan.yellowSeconds) {
      yellowController.text = widget.plan.yellowSeconds.toString();
    }
  }

  @override
  void dispose() {
    greenController.dispose();
    yellowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final updating = widget.isRunning('plan:update:${widget.plan.id}');
    final activating = widget.isRunning('plan:activate:${widget.plan.id}');
    final anyBusy = updating || activating;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDE3DC)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.plan.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (widget.plan.isActive)
                    const Chip(
                      avatar: Icon(Icons.check_circle, size: 18),
                      label: Text('Active'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: greenController,
                      enabled: !anyBusy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Green seconds',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: yellowController,
                      enabled: !anyBusy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Yellow seconds',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!widget.plan.isActive)
                    OutlinedButton.icon(
                      onPressed: anyBusy
                          ? null
                          : () => widget.onActivate(widget.plan),
                      icon: activating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: const Text('Activate'),
                    ),
                  FilledButton.icon(
                    onPressed: anyBusy
                        ? null
                        : () {
                            final green =
                                int.tryParse(greenController.text.trim());
                            final yellow =
                                int.tryParse(yellowController.text.trim());
                            if (green == null || yellow == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Green/yellow seconds must be numbers'),
                                ),
                              );
                              return;
                            }
                            widget.onUpdate(widget.plan, green, yellow);
                          },
                    icon: updating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class RoadsView extends StatelessWidget {
  const RoadsView({
    required this.approaches,
    required this.isRunning,
    required this.onUpdate,
    super.key,
  });

  final List<Approach> approaches;
  final bool Function(String key) isRunning;
  final Future<void> Function(Approach approach, bool isActive) onUpdate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Road approaches and signal heads',
      child: approaches.isEmpty
          ? const EmptyState(text: 'Chưa có approach')
          : Column(
              children: approaches
                  .map(
                    (approach) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: approach.isActive
                          ? const Icon(Icons.traffic)
                          : const Icon(Icons.traffic_outlined),
                      title: Text('${approach.code} - ${approach.name}'),
                      subtitle: Text(
                        '${approach.signalCode} | pins '
                        'R${approach.redPin} Y${approach.yellowPin} '
                        'G${approach.greenPin}',
                      ),
                      value: approach.isActive,
                      onChanged: isRunning('approach:${approach.id}')
                          ? null
                          : (value) => onUpdate(approach, value),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

