import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../data/dashboard_snapshot.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    required this.online,
    required this.loading,
    required this.onRefresh,
    this.showMenu = true,
    super.key,
  });

  final String title;
  final bool online;
  final bool loading;
  final VoidCallback onRefresh;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showMenu)
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu),
              color: AppColors.accent,
            ),
          )
        else
          const SizedBox(width: 48),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: loading ? 'Đang đồng bộ' : 'Làm mới',
          onPressed: loading ? null : onRefresh,
          icon: Icon(loading ? Icons.sync : Icons.refresh),
          color: online ? AppColors.foreground2 : AppColors.warn,
        ),
      ],
    );
  }
}

class DeviceBadge extends StatelessWidget {
  const DeviceBadge({
    required this.deviceId,
    required this.online,
    required this.apiBase,
    super.key,
  });

  final String deviceId;
  final bool online;
  final String apiBase;

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(apiBase)?.host ?? apiBase;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseDot(color: online ? AppColors.success : AppColors.warn),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$deviceId · $host',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.foreground2,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.deviceId,
    required this.online,
    required this.selectedPage,
    required this.onSelect,
    super.key,
  });

  final String deviceId;
  final bool online;
  final String selectedPage;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceId,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      online ? '● Kết nối' : '● Ngoại tuyến',
                      style: TextStyle(
                        color: online ? AppColors.success : AppColors.warn,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              DrawerAction(
                icon: Icons.radio_button_checked,
                label: 'Điều khiển',
                selected: selectedPage == 'control',
                onTap: () => onSelect('control'),
              ),
              DrawerAction(
                icon: Icons.verified_outlined,
                label: 'Trực tiếp',
                selected: selectedPage == 'live',
                onTap: () => onSelect('live'),
              ),
              DrawerAction(
                icon: Icons.description_outlined,
                label: 'Chu kỳ AUTO',
                selected: selectedPage == 'schedule',
                onTap: () => onSelect('schedule'),
              ),
              DrawerAction(
                icon: Icons.monitor_heart_outlined,
                label: 'Nhật ký thiết bị',
                selected: selectedPage == 'logs',
                onTap: () => onSelect('logs'),
              ),
              DrawerAction(
                icon: Icons.settings_outlined,
                label: 'Cài đặt',
                selected: selectedPage == 'settings',
                onTap: () => onSelect('settings'),
              ),
              const Spacer(),
              const Text(
                'IoT Traffic Light',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DrawerAction extends StatelessWidget {
  const DrawerAction({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.glass,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(icon,
          color: selected ? AppColors.accent : AppColors.foreground2),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 12,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: child,
    );
  }
}

class PulseDot extends StatelessWidget {
  const PulseDot({required this.color, this.size = 8, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class StatusStat extends StatelessWidget {
  const StatusStat({
    required this.label,
    required this.value,
    this.color = AppColors.foreground,
    super.key,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        radius: 8,
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class TimingRow extends StatelessWidget {
  const TimingRow({
    required this.color,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    super.key,
  });

  final Color color;
  final String label;
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          RoundIconButton(icon: Icons.remove, onPressed: onMinus),
          SizedBox(
            width: 48,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const Text('s', style: TextStyle(color: AppColors.foreground2)),
          const SizedBox(width: 6),
          RoundIconButton(icon: Icons.add, onPressed: onPlus),
        ],
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton(
      {required this.icon, required this.onPressed, super.key});

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

class SectionCard extends StatelessWidget {
  const SectionCard({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class CommandTile extends StatelessWidget {
  const CommandTile({required this.entry, super.key});

  final CommandEntry entry;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusBg, statusText) =
        commandStatusStyle(entry.deviceStatus);
    final detail = entry.deviceMessage.isNotEmpty
        ? humanizeDeviceMessage(entry.deviceMessage)
        : _commandSummary(entry);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bolt, size: 16, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        commandLabel(
                          entry.command,
                          modeCode: entry.modeCode,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.foreground2,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _commandMeta(entry),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _commandSummary(CommandEntry entry) {
    final mode = entry.modeCode.isEmpty ? entry.command : entry.modeCode;
    return '${entry.command} · ${entry.source} · ${modeLabel(mode)}';
  }

  String _commandMeta(CommandEntry entry) {
    final pieces = <String>[
      if (entry.createdBy.isNotEmpty) entry.createdBy,
      if (entry.createdAt.isNotEmpty) entry.createdAt,
      if (entry.acknowledgedAt.isNotEmpty)
        'ACK ${entry.acknowledgedAt}'
      else if (entry.publishedAt.isNotEmpty)
        'PUB ${entry.publishedAt}',
    ];
    return pieces.isEmpty ? 'Chưa có thêm metadata' : pieces.join(' · ');
  }
}

class LogTile extends StatelessWidget {
  const LogTile({required this.log, super.key});

  final TrafficLog log;

  @override
  Widget build(BuildContext context) {
    final level = logLevel(log);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppColors.space3,
        vertical: AppColors.space2,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              log.createdAt,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: AppColors.space2),
          _LevelPill(level: level),
          const SizedBox(width: AppColors.space2),
          Expanded(
            child: Text(
              '${modeLabel(log.modeCode)} · ${phaseLabel(log.phaseCode)}'
              '${log.remainingSeconds >= 0 ? ' · ${log.remainingSeconds}s' : ''}',
              style: const TextStyle(
                color: AppColors.foreground2,
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String logLevel(TrafficLog log) {
  final mode = log.modeCode.toUpperCase();
  if (mode == 'EMERGENCY') return 'err';
  if (mode == 'NIGHT' || mode == 'MAINTENANCE') return 'warn';
  return 'info';
}

(Color, Color, String) commandStatusStyle(String status) {
  return switch (status) {
    'acknowledged' => (
        AppColors.success,
        const Color(0x3334C759),
        'ĐÃ ACK',
      ),
    'published' => (
        AppColors.accent,
        const Color(0x330071E3),
        'ĐÃ GỬI',
      ),
    'queued' => (
        AppColors.warn,
        const Color(0x33FFCC00),
        'ĐANG CHỜ',
      ),
    'publish_failed' => (
        AppColors.danger,
        const Color(0x33FF3B30),
        'LỖI GỬI',
      ),
    'not_sent' => (
        AppColors.danger,
        const Color(0x33FF3B30),
        'BỊ CHẶN',
      ),
    _ => (
        AppColors.foreground2,
        const Color(0x33636666),
        status.isEmpty ? 'KHÔNG RÕ' : status.toUpperCase(),
      ),
  };
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final (color, bg, text) = switch (level) {
      'err' => (AppColors.danger, const Color(0x33FF3B30), 'ERR'),
      'warn' => (AppColors.warn, const Color(0x33FFCC00), 'WARN'),
      'ok' => (AppColors.success, const Color(0x3334C759), 'OK'),
      _ => (AppColors.accent, const Color(0x330071E3), 'INFO'),
    };
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

enum SnackKind {
  success(Icons.check_circle, Color(0xFF1F7A5B), 2),
  error(Icons.error_outline, Color(0xFFC0392B), 4),
  info(Icons.info_outline, Color(0xFF3D5A80), 3);

  const SnackKind(this.icon, this.color, this.durationSeconds);

  final IconData icon;
  final Color color;
  final int durationSeconds;
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
