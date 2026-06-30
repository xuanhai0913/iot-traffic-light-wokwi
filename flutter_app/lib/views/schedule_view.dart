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
    final activePlans = widget.phasePlans.where((plan) => plan.isActive);
    final activePlan = activePlans.isEmpty ? null : activePlans.first;
    final displayedPlan = activePlan ??
        (widget.phasePlans.isEmpty ? null : widget.phasePlans.first);
    final green = displayedPlan?.greenSeconds ?? 0;
    final yellow = displayedPlan?.yellowSeconds ?? 0;
    final red = green + yellow;
    final updatingPlan = displayedPlan != null &&
        widget.isRunning('plan:update:${displayedPlan.id}');
    final activatingPlan = displayedPlan != null &&
        widget.isRunning('plan:activate:${displayedPlan.id}');
    final planBusy = updatingPlan || activatingPlan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        activePlan == null
                            ? 'Chưa có chu kỳ AUTO hoạt động'
                            : 'Chu kỳ AUTO đang hoạt động',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                        displayedPlan == null
                            ? 'Backend chưa trả về cấu hình chu kỳ.'
                            : activePlan == null
                                ? '${displayedPlan.name} · chưa được kích hoạt'
                                : '${displayedPlan.name} · dùng để tính pha AUTO',
                        style: const TextStyle(
                            color: AppColors.foreground2, fontSize: 12)),
                  ],
                ),
              ),
              if (updatingPlan || activatingPlan)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (activePlan != null)
                const Icon(Icons.check_circle, color: AppColors.success)
              else
                IconButton.filled(
                  tooltip: 'Kích hoạt chu kỳ này',
                  onPressed: displayedPlan == null
                      ? null
                      : () => widget.onActivatePlan(displayedPlan),
                  icon: const Icon(Icons.play_arrow),
                ),
            ],
          ),
        ),
        const SectionLabel('Thời gian chu kỳ (giây)'),
        if (displayedPlan == null)
          const GlassPanel(
            child: EmptyState(text: 'Chưa có cấu hình thời gian để chỉnh sửa.'),
          )
        else ...[
          TimingRow(
            color: AppColors.danger,
            label: 'Đèn đỏ (tự tính)',
            value: red,
            onMinus: null,
            onPlus: null,
          ),
          const SizedBox(height: 6),
          TimingRow(
            color: AppColors.warn,
            label: 'Đèn vàng',
            value: yellow,
            onMinus: planBusy || yellow <= 2
                ? null
                : () => widget.onUpdatePlan(
                      displayedPlan,
                      green,
                      yellow - 1,
                    ),
            onPlus: planBusy
                ? null
                : () => widget.onUpdatePlan(
                      displayedPlan,
                      green,
                      yellow + 1,
                    ),
          ),
          const SizedBox(height: 6),
          TimingRow(
            color: AppColors.success,
            label: 'Đèn xanh',
            value: green,
            onMinus: planBusy || green <= 5
                ? null
                : () => widget.onUpdatePlan(
                      displayedPlan,
                      green - 5,
                      yellow,
                    ),
            onPlus: planBusy
                ? null
                : () => widget.onUpdatePlan(
                      displayedPlan,
                      green + 5,
                      yellow,
                    ),
          ),
        ],
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
      title: 'Luồng đường và chân đèn',
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
                        '${approach.signalCode} · chân '
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
