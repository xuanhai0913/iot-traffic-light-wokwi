import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../data/dashboard_snapshot.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    required this.online,
    required this.loading,
    required this.onRefresh,
    super.key,
  });

  final String title;
  final bool online;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
            color: AppColors.accent,
          ),
        ),
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
          icon: Icon(loading ? Icons.sync : Icons.settings_outlined),
          color: online ? AppColors.foreground2 : AppColors.warn,
        ),
      ],
    );
  }
}


class DeviceBadge extends StatelessWidget {
  const DeviceBadge({required this.online, required this.apiBase, super.key});

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
                'TrafficLight-01 · $host',
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
    required this.online,
    required this.selectedPage,
    required this.onSelect,
    super.key,
  });

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
                    const Text(
                      'TrafficLight-01',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                icon: Icons.description_outlined,
                label: 'Phase Plans',
                selected: selectedPage == 'schedule',
                onTap: () => onSelect('schedule'),
              ),
              DrawerAction(
                icon: Icons.monitor_heart_outlined,
                label: 'Device Logs',
                selected: selectedPage == 'logs',
                onTap: () => onSelect('logs'),
              ),
              DrawerAction(
                icon: Icons.chat_bubble_outline,
                label: 'Commands Log',
                selected: selectedPage == 'logs',
                onTap: () => onSelect('logs'),
              ),
              DrawerAction(
                icon: Icons.warning_amber_rounded,
                label: 'Alerts',
                selected: false,
                onTap: () => onSelect('logs'),
              ),
              const Divider(color: AppColors.glassBorder, height: 24),
              DrawerAction(
                icon: Icons.help_outline,
                label: 'Hướng dẫn',
                selected: false,
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
      leading: Icon(icon, color: selected ? AppColors.accent : AppColors.foreground2),
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
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.bolt),
      title: Text(entry.command),
      subtitle: Text('${entry.source} - ${entry.status}'),
      trailing: Text(entry.createdAt),
    );
  }
}


class LogTile extends StatelessWidget {
  const LogTile({required this.log, super.key});

  final TrafficLog log;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.receipt_long),
      title: Text(log.phaseCode),
      subtitle: Text('${log.modeCode} - remaining ${log.remainingSeconds}s'),
      trailing: Text(log.createdAt),
    );
  }
}


class StatusBanner extends StatelessWidget {
  const StatusBanner({required this.status, required this.online, super.key});

  final String status;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: online ? const Color(0xFFE6F4EA) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: online ? const Color(0xFFA8D5B8) : const Color(0xFFFFCC80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              online ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: 18,
              color: online
                  ? const Color(0xFF1F7A5B)
                  : const Color(0xFFB26A00),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(status)),
          ],
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

