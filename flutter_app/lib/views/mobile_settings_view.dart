import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../data/dashboard_snapshot.dart';
import '../widgets/atoms.dart';

class MobileSettingsView extends StatelessWidget {
  const MobileSettingsView({
    required this.controller,
    required this.online,
    required this.apiBase,
    required this.isRunning,
    required this.deviceStatuses,
    required this.phasePlans,
    required this.skipDangerConfirm,
    required this.onApply,
    required this.onRefresh,
    required this.onToggleSkipConfirm,
    super.key,
  });

  final TextEditingController controller;
  final bool online;
  final String apiBase;
  final bool Function(String key) isRunning;
  final List<Map<String, dynamic>> deviceStatuses;
  final List<PhasePlan> phasePlans;
  final bool skipDangerConfirm;
  final Future<void> Function() onApply;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onToggleSkipConfirm;

  @override
  Widget build(BuildContext context) {
    final applying = isRunning('apply-url');
    final refreshing = isRunning('refresh');
    final parsedHost = Uri.tryParse(apiBase)?.host ?? '';
    final host = parsedHost.isEmpty ? apiBase : parsedHost;
    final primaryDevice = deviceStatuses.isEmpty ? null : deviceStatuses.first;
    final activePlan = phasePlans.where((plan) => plan.isActive).isEmpty
        ? (phasePlans.isEmpty ? null : phasePlans.first)
        : phasePlans.firstWhere((plan) => plan.isActive);
    final lastSeenRaw = compactTime(primaryDevice?['last_seen_at']);
    final lastSeen = lastSeenRaw.isEmpty ? '—' : lastSeenRaw;
    final deviceState = text(primaryDevice?['connection_state'], '');
    final deviceMode = text(primaryDevice?['last_mode_code'], '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Trạng thái thiết bị'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppColors.space2,
          crossAxisSpacing: AppColors.space2,
          childAspectRatio: 1.4,
          children: [
            _StatCard(
              value: online ? 'Hoạt động' : 'Mất kết nối',
              label: 'Backend',
              color: online ? AppColors.success : AppColors.warn,
            ),
            _StatCard(
              value: _deviceStateLabel(deviceState),
              label: 'Thiết bị',
              color: deviceState.toLowerCase() == 'online'
                  ? AppColors.success
                  : AppColors.warn,
            ),
            _StatCard(
              value: modeLabel(deviceMode),
              label: 'Chế độ cuối',
              color: AppColors.accent,
            ),
            _StatCard(
              value: lastSeen,
              label: 'Lần thấy cuối',
              color: primaryDevice == null
                  ? AppColors.foreground2
                  : AppColors.warn,
            ),
          ],
        ),
        const SizedBox(height: AppColors.space3),
        const SectionLabel('Cài đặt thiết bị'),
        GlassPanel(
          child: Column(
            children: [
              TextField(
                controller: controller,
                enabled: !applying,
                style: const TextStyle(color: AppColors.foreground),
                decoration: InputDecoration(
                  labelText: 'Địa chỉ API',
                  hintText: 'http://10.0.2.2:8000',
                  prefixIcon: const Icon(Icons.link),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.url,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                onSubmitted: (_) => onApply(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: applying ? null : onApply,
                      icon: applying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Lưu'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: refreshing ? null : onRefresh,
                      icon: refreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Kiểm tra'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SettingRow(
          icon: Icons.network_wifi,
          iconColor: AppColors.accent,
          label: 'Máy chủ API',
          desc: 'Đang sử dụng',
          value: host,
        ),
        SettingRow(
          icon: Icons.memory,
          iconColor: AppColors.success,
          label: 'Mã thiết bị',
          desc: 'Nhận từ heartbeat',
          value: text(primaryDevice?['device_id'], 'TrafficLight-01'),
        ),
        SettingRow(
          icon: Icons.schedule,
          iconColor: AppColors.warn,
          label: 'Cấu hình chu kỳ',
          desc: 'Xanh/Vàng ở backend',
          value: activePlan == null
              ? '—'
              : '${activePlan.greenSeconds}/${activePlan.yellowSeconds}s',
        ),
        SettingRow(
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.danger,
          label: 'Xác nhận lệnh rủi ro',
          desc: skipDangerConfirm ? 'Đang bỏ qua cảnh báo' : 'Luôn hỏi trước',
          value: skipDangerConfirm ? 'Tắt' : 'Bật',
          trailing: Switch(
            value: !skipDangerConfirm,
            activeThumbColor: AppColors.success,
            onChanged: (value) => onToggleSkipConfirm(!value),
          ),
        ),
      ],
    );
  }

  String _deviceStateLabel(String value) {
    return switch (value.toLowerCase()) {
      'online' => 'Đang kết nối',
      'offline' => 'Mất kết nối',
      _ => 'Chưa có dữ liệu',
    };
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.desc = '',
    this.value = '',
    this.trailing,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String desc;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: GlassPanel(
        radius: 8,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  if (desc.isNotEmpty)
                    Text(desc,
                        style: const TextStyle(
                            color: AppColors.foreground2, fontSize: 11)),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (value.isNotEmpty)
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.foreground2, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.color = AppColors.foreground,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.all(AppColors.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppColors.space2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.foreground2,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
