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
    final host = Uri.tryParse(apiBase)?.host ?? apiBase;
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
              value: online ? '●' : '!',
              label: online ? 'Connected' : 'Offline',
              color: online ? AppColors.success : AppColors.warn,
            ),
            const _StatCard(value: '—', label: 'RSSI (dBm)'),
            const _StatCard(value: '—', label: 'Nhiệt độ'),
            _StatCard(
              value: online ? '● live' : '—',
              label: 'Uptime',
              color: online ? AppColors.success : AppColors.foreground2,
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
                  labelText: 'API base URL',
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
                      label: const Text('Test'),
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
          label: 'Địa chỉ IP',
          desc: 'Cấu hình mạng',
          value: host,
        ),
        SettingRow(
          icon: Icons.memory,
          iconColor: AppColors.success,
          label: 'Tên thiết bị',
          desc: 'Đổi tên',
          value: deviceStatuses.isEmpty
              ? 'TrafficLight-01'
              : text(deviceStatuses.first['device_id'], 'TrafficLight-01'),
        ),
        SettingRow(
          icon: Icons.schedule,
          iconColor: AppColors.warn,
          label: 'Cấu hình chu kỳ',
          desc: 'Đỏ, Vàng, Xanh',
          value: phasePlans.isEmpty
              ? '—'
              : '${phasePlans.first.greenSeconds}/${phasePlans.first.yellowSeconds}s',
        ),
        SettingRow(
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.danger,
          label: 'Xác nhận lệnh rủi ro',
          desc: skipDangerConfirm ? 'Đang bỏ qua cảnh báo' : 'Luôn hỏi trước',
          value: skipDangerConfirm ? 'Tắt' : 'Bật',
          trailing: Switch(
            value: !skipDangerConfirm,
            activeColor: AppColors.success,
            onChanged: (value) => onToggleSkipConfirm(!value),
          ),
        ),
        const SectionLabel('Thông tin'),
        const SettingRow(
          icon: Icons.info_outline,
          iconColor: AppColors.foreground2,
          label: 'Phiên bản firmware',
          value: '—',
        ),
        const SettingRow(
          icon: Icons.shield_outlined,
          iconColor: AppColors.foreground2,
          label: 'Bảo mật',
          desc: '—',
        ),
      ],
    );
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
                  style:
                      const TextStyle(color: AppColors.foreground2, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class SettingsView extends StatelessWidget {
  const SettingsView({
    required this.controller,
    required this.online,
    required this.apiBase,
    required this.isRunning,
    required this.deviceStatuses,
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
  final bool skipDangerConfirm;
  final Future<void> Function() onApply;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onToggleSkipConfirm;

  @override
  Widget build(BuildContext context) {
    final applying = isRunning('apply-url');
    final refreshing = isRunning('refresh');
    return SectionCard(
      title: 'Backend connection',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            enabled: !applying,
            decoration: const InputDecoration(
              labelText: 'API base URL',
              hintText: 'http://10.0.2.2:8000',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => onApply(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: applying ? null : onApply,
                  icon: applying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Apply'),
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
                  label: const Text('Test'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(online ? 'Connected' : 'Offline',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Endpoint: $apiBase'),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.warning_amber_rounded),
            title: const Text('Confirm risky commands'),
            subtitle: Text(
              skipDangerConfirm
                  ? 'EMERGENCY and PRIORITY modes send without asking.'
                  : 'Ask before sending EMERGENCY and PRIORITY modes.',
            ),
            value: !skipDangerConfirm,
            onChanged: (value) => onToggleSkipConfirm(!value),
          ),
          const SizedBox(height: 16),
          Text('ESP32 devices', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (deviceStatuses.isEmpty)
            const Text('Chưa nhận heartbeat/status từ Wokwi')
          else
            ...deviceStatuses.map(
              (device) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  text(device['connection_state'], 'offline') == 'online'
                      ? Icons.memory
                      : Icons.memory_outlined,
                ),
                title: Text(text(device['device_id'], 'ESP32')),
                subtitle: Text(
                  'Last seen: ${compactTime(device['last_seen_at'])}',
                ),
                trailing: Text(
                  text(device['connection_state'], 'offline').toUpperCase(),
                ),
              ),
            ),
        ],
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
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.0,
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

