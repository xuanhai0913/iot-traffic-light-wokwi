import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TrafficOperatorApp());
}

class AppColors {
  static const background = Color(0xFF121212);
  static const surface = Color(0xFF1E1E1E);
  static const surface2 = Color(0xFF2C2C2C);
  static const foreground = Color(0xFFFFFFFF);
  static const foreground2 = Color(0xFFA0A0A0);
  static const muted = Color(0xFF666666);
  static const glass = Color(0x0DFFFFFF);
  static const glassBorder = Color(0x12FFFFFF);
  static const accent = Color(0xFF0071E3);
  static const danger = Color(0xFFFF3B30);
  static const warn = Color(0xFFFFCC00);
  static const success = Color(0xFF34C759);
}

class TrafficOperatorApp extends StatefulWidget {
  const TrafficOperatorApp({super.key});

  @override
  State<TrafficOperatorApp> createState() => _TrafficOperatorAppState();
}

class _TrafficOperatorAppState extends State<TrafficOperatorApp> {
  // GlobalKey for the root ScaffoldMessenger. Wired into MaterialApp so that
  // SnackBars and dialogs from anywhere in the tree resolve correctly (web,
  // mobile, and desktop). Earlier this key was attached as Scaffold.key,
  // which silently failed at runtime because Scaffold does not host a
  // ScaffoldMessenger element.
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final home = TrafficHomePage(messengerKey: _messengerKey);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoApp(
        debugShowCheckedModeBanner: false,
        title: 'IoT Traffic Light',
        theme: const CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: AppColors.accent,
          scaffoldBackgroundColor: AppColors.background,
          barBackgroundColor: AppColors.surface,
        ),
        home: home,
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      title: 'IoT Traffic Light',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.danger,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.foreground,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.glass,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.accent.withValues(alpha: 0.16),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.muted,
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.glass,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: AppColors.glassBorder),
          ),
        ),
        textTheme: Typography.whiteMountainView.apply(
          bodyColor: AppColors.foreground,
          displayColor: AppColors.foreground,
        ),
      ),
      home: home,
    );
  }
}

class TrafficHomePage extends StatefulWidget {
  const TrafficHomePage({required this.messengerKey, super.key});

  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  State<TrafficHomePage> createState() => _TrafficHomePageState();
}

class _TrafficHomePageState extends State<TrafficHomePage> {
  final TextEditingController apiController =
      TextEditingController(text: defaultApiBase);

  // Pulled from the parent widget so the same key is wired into MaterialApp's
  // ScaffoldMessenger (see TrafficOperatorApp). Do not redeclare a fresh key
  // here; doing so would orphan the messenger and re-introduce the bug where
  // SnackBars and dialogs silently no-op on Flutter web.
  late final GlobalKey<ScaffoldMessengerState> _messengerKey =
      widget.messengerKey;
  late ApiClient api = ApiClient(defaultApiBase);
  SettingsStore? _settings;
  Timer? pollTimer;

  DashboardSnapshot dashboard = DashboardSnapshot.empty();
  final Set<String> _runningActions = <String>{};
  bool online = false;
  bool skipDangerConfirm = false;
  String selectedPage = 'control';
  DateTime? _lastSnapshotAt;

  bool isRunning(String key) => _runningActions.contains(key);
  bool get anyLoading => _runningActions.isNotEmpty;

  void _setRunning(String key, bool value) {
    setState(() {
      if (value) {
        _runningActions.add(key);
      } else {
        _runningActions.remove(key);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
    pollTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => refreshStatusOnly());
  }

  Future<void> _bootstrap() async {
    try {
      final store = await SettingsStore.open();
      final savedBase = store.readApiBase();
      final savedSkipConfirm = store.readSkipConfirm();
      if (savedBase != null && mounted) {
        setState(() {
          api = ApiClient(savedBase);
          apiController.text = savedBase;
          skipDangerConfirm = savedSkipConfirm;
        });
      } else if (mounted) {
        setState(() {
          skipDangerConfirm = savedSkipConfirm;
        });
      }
      _settings = store;
    } catch (error) {
      // Persistent settings are optional; the app still works with
      // the default API URL if SharedPreferences is unavailable.
    }
    await refreshDashboard();
  }

  Future<void> toggleSkipConfirm(bool value) async {
    setState(() {
      skipDangerConfirm = value;
    });
    final store = _settings;
    if (store == null) {
      return;
    }
    try {
      await store.writeSkipConfirm(value);
    } catch (_) {
      _showSnack(SnackKind.info, 'Không lưu được setting local');
    }
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    apiController.dispose();
    super.dispose();
  }

  Future<void> refreshDashboard({bool force = false}) async {
    if (isRunning('refresh') && !force) {
      return;
    }

    _setRunning('refresh', true);

    try {
      final data = await api.getJson('/api/intersections/1/dashboard');
      if (!mounted) return;
      setState(() {
        dashboard =
            DashboardSnapshot.fromJson(data['data'] as Map<String, dynamic>);
        online = true;
        _lastSnapshotAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        online = false;
      });
      if (force) {
        _showSnack(SnackKind.error, error.toString());
      }
    } finally {
      if (mounted) {
        _setRunning('refresh', false);
      }
    }
  }

  Future<void> refreshStatusOnly() async {
    if (!online) {
      return;
    }
    // Skip the silent poll while any user-initiated action is running so
    // we do not pile up parallel GET /status calls.
    if (anyLoading) {
      return;
    }

    try {
      final data = await api.getJson('/api/intersections/1/status');
      if (!mounted) return;
      setState(() {
        dashboard = dashboard.copyWith(
          status: TrafficStatus.fromJson(data['data'] as Map<String, dynamic>),
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          online = false;
        });
      }
    }
  }

  Future<void> sendCommand(String modeCode) async {
    final key = 'cmd:$modeCode';
    if (isRunning(key)) {
      return;
    }

    final danger = DangerLevel.forMode(modeCode);
    if (danger != DangerLevel.safe && _requireConfirm(danger)) {
      final confirmed = await _showDangerConfirmDialog(modeCode, danger);
      if (confirmed != true) {
        return;
      }
    }

    _setRunning(key, true);

    try {
      final data = await api.postJson('/api/intersections/1/commands', {
        'command': 'SET_$modeCode',
        'modeCode': modeCode,
        'source': 'flutter',
        'createdBy': 'operator',
      });

      final result = data['data'] as Map<String, dynamic>;
      await refreshDashboard(force: true);
      if (!mounted) return;
      setState(() {
        online = true;
      });
      _showCommandResultDialog(result);
    } catch (error) {
      _showSnack(SnackKind.error, error.toString());
    } finally {
      if (mounted) {
        _setRunning(key, false);
      }
    }
  }

  bool _requireConfirm(DangerLevel danger) {
    final store = _settings;
    if (store == null) {
      return true;
    }
    if (store.readSkipConfirm() && danger != DangerLevel.critical) {
      return false;
    }
    return true;
  }

  Future<bool?> _showDangerConfirmDialog(
      String modeCode, DangerLevel danger) async {
    final messenger = _messengerKey.currentState;
    if (messenger == null) {
      return null;
    }
    final dialogContext = messenger.context;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return showCupertinoDialog<bool>(
        context: dialogContext,
        barrierDismissible: false,
        builder: (ctx) => DangerousCommandDialog(
          modeCode: modeCode,
          danger: danger,
          isIOS: true,
        ),
      );
    }
    return showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (_) => DangerousCommandDialog(
        modeCode: modeCode,
        danger: danger,
      ),
    );
  }

  Future<void> _showCommandResultDialog(Map<String, dynamic> result) async {
    final messenger = _messengerKey.currentState;
    if (messenger == null) {
      return;
    }
    final command = result['command']?.toString() ?? 'SET_?';
    final commandId = result['commandId'] ?? result['id'] ?? '-';
    final modeCode = result['modeCode']?.toString() ?? '-';
    final source = result['source']?.toString() ?? '-';
    final createdBy = result['createdBy']?.toString() ?? '-';
    final createdAt = compactTime(result['createdAt'] ?? result['created_at']);
    final deviceStatus = result['deviceStatus']?.toString() ?? 'queued';
    final String commandIdDisplay = commandId.toString();
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    Future<void> Function() showIt = isIOS
        ? () => showCupertinoDialog<void>(
              context: messenger.context,
              builder: (ctx) => CommandResultDialog(
                command: command,
                commandId: commandIdDisplay,
                modeCode: modeCode,
                source: source,
                createdBy: createdBy,
                createdAt: createdAt,
                deviceStatus: deviceStatus,
                isIOS: true,
              ),
            )
        : () => showDialog<void>(
              context: messenger.context,
              builder: (ctx) => CommandResultDialog(
                command: command,
                commandId: commandIdDisplay,
                modeCode: modeCode,
                source: source,
                createdBy: createdBy,
                createdAt: createdAt,
                deviceStatus: deviceStatus,
              ),
            );

    await showIt();
  }

  Future<void> updatePhasePlan(
      PhasePlan plan, int greenSeconds, int yellowSeconds) async {
    final key = 'plan:update:${plan.id}';
    if (isRunning(key)) {
      return;
    }
    _setRunning(key, true);

    try {
      await api.putJson('/api/phase-plans/${plan.id}', {
        'greenSeconds': greenSeconds,
        'yellowSeconds': yellowSeconds,
      });
      await refreshDashboard(force: true);
      if (!mounted) return;
      setState(() {
        online = true;
      });
      _showSnack(SnackKind.success, 'Đã cập nhật phase plan ${plan.name}');
    } catch (error) {
      _showSnack(SnackKind.error, error.toString());
    } finally {
      if (mounted) {
        _setRunning(key, false);
      }
    }
  }

  Future<void> activatePhasePlan(PhasePlan plan) async {
    final key = 'plan:activate:${plan.id}';
    if (isRunning(key)) {
      return;
    }
    _setRunning(key, true);

    try {
      await api.postJson('/api/phase-plans/${plan.id}/activate', {});
      await refreshDashboard(force: true);
      if (!mounted) return;
      setState(() {
        online = true;
      });
      _showSnack(SnackKind.success, 'Đã kích hoạt phase plan ${plan.name}');
    } catch (error) {
      _showSnack(SnackKind.error, error.toString());
    } finally {
      if (mounted) {
        _setRunning(key, false);
      }
    }
  }

  Future<void> updateApproach(Approach approach, bool isActive) async {
    final key = 'approach:${approach.id}';
    if (isRunning(key)) {
      return;
    }
    _setRunning(key, true);

    try {
      await api.putJson('/api/approaches/${approach.id}', {
        'name': approach.name,
        'displayOrder': approach.displayOrder,
        'isActive': isActive,
      });
      await refreshDashboard(force: true);
      if (!mounted) return;
      setState(() {
        online = true;
      });
      _showSnack(
        SnackKind.success,
        '${approach.code} đã ${isActive ? 'bật' : 'tắt'} trên backend',
      );
    } catch (error) {
      _showSnack(SnackKind.error, error.toString());
    } finally {
      if (mounted) {
        _setRunning(key, false);
      }
    }
  }

  Future<void> applyApiBase() async {
    if (isRunning('apply-url')) {
      return;
    }
    _setRunning('apply-url', true);

    try {
      final value = apiController.text.trim().replaceAll(RegExp(r'/+$'), '');
      if (value.isEmpty) {
        _showSnack(SnackKind.error, 'API URL không được để trống');
        return;
      }

      setState(() {
        api = ApiClient(value);
        online = false;
      });

      // Persist for next launch so the operator does not have to
      // re-enter the URL on a real Android device.
      final store = _settings;
      if (store != null) {
        try {
          await store.writeApiBase(value);
        } catch (_) {
          _showSnack(SnackKind.info, 'Không lưu được API URL local');
        }
      }

      await refreshDashboard();
      if (!mounted) return;
      if (online) {
        _showSnack(SnackKind.success, 'Đã kết nối $value');
      }
    } finally {
      if (mounted) {
        _setRunning('apply-url', false);
      }
    }
  }

  void _showSnack(SnackKind kind, String text) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(kind.icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
        backgroundColor: kind.color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: kind.durationSeconds),
      ),
    );
  }

  String get connectionLabel {
    if (anyLoading) {
      return 'Đang đồng bộ backend ...';
    }
    return online ? 'Backend sẵn sàng' : 'Mất kết nối backend';
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (selectedPage) {
      'control' => ControlView(
          snapshot: dashboard,
          currentMode: dashboard.status.modeCode,
          isRunning: isRunning,
          onCommand: sendCommand,
        ),
      'live' => LiveStatusView(snapshot: dashboard, lastSnapshotAt: _lastSnapshotAt),
      'schedule' => ManageView(
          phasePlans: dashboard.phasePlans,
          approaches: dashboard.approaches,
          isRunning: isRunning,
          onUpdatePlan: updatePhasePlan,
          onActivatePlan: activatePhasePlan,
          onUpdateApproach: updateApproach,
        ),
      'logs' => HistoryView(commands: dashboard.commands, logs: dashboard.logs),
      'settings' => MobileSettingsView(
          controller: apiController,
          online: online,
          apiBase: api.baseUrl,
          isRunning: isRunning,
          deviceStatuses: dashboard.deviceStatuses,
          phasePlans: dashboard.phasePlans,
          skipDangerConfirm: skipDangerConfirm,
          onApply: applyApiBase,
          onRefresh: refreshDashboard,
          onToggleSkipConfirm: toggleSkipConfirm,
        ),
      _ => ControlView(
          snapshot: dashboard,
          currentMode: dashboard.status.modeCode,
          isRunning: isRunning,
          onCommand: sendCommand,
        ),
    };

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS uses CupertinoTabScaffold; the body is the same content tree
      // (AppHeader + DeviceBadge + AnimatedSwitcher), wrapped per-tab in
      // CupertinoTabView so each tab keeps its own Navigator stack.
      return CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          backgroundColor: AppColors.surface,
          activeColor: AppColors.accent,
          inactiveColor: AppColors.muted,
          currentIndex: switch (selectedPage) {
            'live' => 1,
            'schedule' => 2,
            'settings' => 3,
            _ => 0,
          },
          onTap: (index) {
            setState(() {
              selectedPage =
                  ['control', 'live', 'schedule', 'settings'][index];
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.radio_button_checked),
              label: 'Điều khiển',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.verified_outlined),
              label: 'Trực tiếp',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule_outlined),
              label: 'Lịch',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              label: 'Cài đặt',
            ),
          ],
        ),
        tabBuilder: (context, _) {
          return CupertinoTabView(
            builder: (tabContext) {
              return CupertinoPageScaffold(
                backgroundColor: AppColors.background,
                child: SafeArea(
                  child: RefreshIndicator(
                    onRefresh: refreshDashboard,
                    color: AppColors.accent,
                    backgroundColor: AppColors.surface,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 88),
                      children: [
                        AppHeader(
                          title: _pageTitle(selectedPage),
                          online: online,
                          loading: anyLoading,
                          onRefresh: () => refreshDashboard(force: true),
                        ),
                        const SizedBox(height: 8),
                        DeviceBadge(
                            online: online, apiBase: api.baseUrl),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: KeyedSubtree(
                            key: ValueKey(selectedPage),
                            child: content,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }
    return Scaffold(
      drawer: AppDrawer(
        online: online,
        selectedPage: selectedPage,
        onSelect: (page) {
          Navigator.of(context).pop();
          setState(() {
            selectedPage = page;
          });
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshDashboard,
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 88),
            children: [
              AppHeader(
                title: _pageTitle(selectedPage),
                online: online,
                loading: anyLoading,
                onRefresh: () => refreshDashboard(force: true),
              ),
              const SizedBox(height: 8),
              DeviceBadge(online: online, apiBase: api.baseUrl),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: KeyedSubtree(
                  key: ValueKey(selectedPage),
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.glass,
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: NavigationBar(
          selectedIndex: switch (selectedPage) {
            'live' => 1,
            'schedule' => 2,
            'settings' => 3,
            _ => 0,
          },
          onDestinationSelected: (index) {
            setState(() {
              selectedPage = ['control', 'live', 'schedule', 'settings'][index];
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.radio_button_checked),
              selectedIcon: Icon(Icons.radio_button_checked),
              label: 'Điều khiển',
            ),
            NavigationDestination(
              icon: Icon(Icons.verified_outlined),
              selectedIcon: Icon(Icons.verified),
              label: 'Trực tiếp',
            ),
            NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              selectedIcon: Icon(Icons.schedule),
              label: 'Lịch',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }

  String _pageTitle(String page) {
    return switch (page) {
      'control' => 'Dashboard',
      'live' => 'Trạng thái',
      'schedule' => 'Auto Cycle',
      'logs' => 'Device Logs',
      'settings' => 'Cài đặt & Trạng thái',
      _ => 'Dashboard',
    };
  }
}

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

class TrafficLampStack extends StatelessWidget {
  const TrafficLampStack({required this.activeColor, this.large = true, super.key});

  final String activeColor;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 96.0 : 42.0;
    return Container(
      width: large ? 180 : 76,
      padding: EdgeInsets.all(large ? 20 : 10),
      decoration: BoxDecoration(
        color: const Color(0xDD111111),
        borderRadius: BorderRadius.circular(large ? 28 : 14),
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SignalLamp(color: 'RED', active: activeColor == 'RED', size: size),
          SizedBox(height: large ? 12 : 6),
          SignalLamp(
              color: 'YELLOW', active: activeColor == 'YELLOW', size: size),
          SizedBox(height: large ? 12 : 6),
          SignalLamp(color: 'GREEN', active: activeColor == 'GREEN', size: size),
        ],
      ),
    );
  }
}

class SignalLamp extends StatelessWidget {
  const SignalLamp({
    required this.color,
    required this.active,
    required this.size,
    super.key,
  });

  final String color;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = switch (color) {
      'RED' => AppColors.danger,
      'YELLOW' => AppColors.warn,
      'GREEN' => AppColors.success,
      _ => AppColors.muted,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? base : const Color(0xFF1A1A1A),
        border: Border.all(
          color: active ? base : AppColors.surface2,
          width: 2,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: base.withValues(alpha: 0.42),
                  blurRadius: size * 0.34,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
    );
  }
}

class ModeChip extends StatelessWidget {
  const ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.glass,
      side: BorderSide(
        color: active ? AppColors.accent : AppColors.glassBorder,
      ),
      labelStyle: TextStyle(
        color: active ? Colors.white : AppColors.foreground2,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class MiniCommandButton extends StatelessWidget {
  const MiniCommandButton({
    required this.modeCode,
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.loading,
    required this.onPressed,
    super.key,
  });

  final String modeCode;
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final bool loading;
  final Future<void> Function(String modeCode) onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 44,
        child: FilledButton.icon(
          onPressed: loading ? null : () => onPressed(modeCode),
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

class ControlView extends StatelessWidget {
  const ControlView({
    required this.snapshot,
    required this.currentMode,
    required this.isRunning,
    required this.onCommand,
    super.key,
  });

  final DashboardSnapshot snapshot;
  final String currentMode;
  final bool Function(String key) isRunning;
  final Future<void> Function(String modeCode) onCommand;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.status;
    final activeColor = _activeColor(status);
    final countdown =
        status.remainingSeconds >= 0 ? '${status.remainingSeconds}s' : '--';
    final isCycle = currentMode == 'AUTO';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ModeChip(
              label: 'Manual',
              active: !isCycle,
              onTap: currentMode == 'AUTO'
                  ? () => onCommand('NIGHT')
                  : () {},
            ),
            const SizedBox(width: 8),
            ModeChip(
              label: 'Auto Cycle',
              active: isCycle,
              onTap: () => onCommand('AUTO'),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                    label: 'Trạng thái',
                    value: currentMode == 'EMERGENCY' ? 'Khẩn cấp' : 'Đang bật',
                    color: currentMode == 'EMERGENCY'
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  StatusStat(
                    label: 'Chu kỳ',
                    value: modeLabel(currentMode),
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  const StatusStat(
                    label: 'Nhiệt độ',
                    value: '—',
                    color: AppColors.foreground2,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            MiniCommandButton(
              modeCode: 'AUTO',
              label: 'Auto',
              icon: Icons.autorenew,
              color: AppColors.accent,
              active: currentMode == 'AUTO',
              loading: isRunning('cmd:AUTO'),
              onPressed: onCommand,
            ),
            const SizedBox(width: 8),
            MiniCommandButton(
              modeCode: 'NIGHT',
              label: 'Night',
              icon: Icons.nightlight_round,
              color: AppColors.warn,
              active: currentMode == 'NIGHT',
              loading: isRunning('cmd:NIGHT'),
              onPressed: onCommand,
            ),
            const SizedBox(width: 8),
            MiniCommandButton(
              modeCode: 'EMERGENCY',
              label: 'Stop',
              icon: Icons.stop_rounded,
              color: AppColors.danger,
              active: currentMode == 'EMERGENCY',
              loading: isRunning('cmd:EMERGENCY'),
              onPressed: onCommand,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            MiniCommandButton(
              modeCode: 'PRIORITY_NS',
              label: 'NS',
              icon: Icons.swap_vert,
              color: AppColors.success,
              active: currentMode == 'PRIORITY_NS',
              loading: isRunning('cmd:PRIORITY_NS'),
              onPressed: onCommand,
            ),
            const SizedBox(width: 8),
            MiniCommandButton(
              modeCode: 'PRIORITY_EW',
              label: 'EW',
              icon: Icons.swap_horiz,
              color: AppColors.success,
              active: currentMode == 'PRIORITY_EW',
              loading: isRunning('cmd:PRIORITY_EW'),
              onPressed: onCommand,
            ),
          ],
        ),
      ],
    );
  }

  String _activeColor(TrafficStatus status) {
    if (status.signals.isNotEmpty) {
      final active = status.signals.firstWhere(
        (signal) => signal.color != 'OFF',
        orElse: () => status.signals.first,
      );
      return active.color;
    }
    return switch (status.phaseCode) {
      'NS_GREEN' || 'EW_GREEN' => 'GREEN',
      'NS_YELLOW' || 'EW_YELLOW' => 'YELLOW',
      _ => 'RED',
    };
  }

  String _colorVietnamese(String color) {
    return switch (color) {
      'GREEN' => 'Đèn xanh',
      'YELLOW' => 'Đèn vàng',
      'RED' => 'Đèn đỏ',
      _ => 'Đèn tắt',
    };
  }
}

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

class HistoryView extends StatelessWidget {
  const HistoryView({required this.commands, required this.logs, super.key});

  final List<CommandEntry> commands;
  final List<TrafficLog> logs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Command history',
          child: commands.isEmpty
              ? const EmptyState(text: 'Chưa có command')
              : Column(
                  children: commands
                      .map((entry) => CommandTile(entry: entry))
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Device logs',
          child: logs.isEmpty
              ? const EmptyState(text: 'Chưa có log')
              : Column(
                  children: logs.map((log) => LogTile(log: log)).toList(),
                ),
        ),
      ],
    );
  }
}

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
        Row(
          children: [
            StatusStat(
              label: online ? 'Kết nối' : 'Offline',
              value: online ? '●' : '!',
              color: online ? AppColors.success : AppColors.warn,
            ),
            const SizedBox(width: 6),
            const StatusStat(
              label: 'RSSI',
              value: '—',
              color: AppColors.foreground2,
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            StatusStat(label: 'Nhiệt độ', value: '—'),
            SizedBox(width: 6),
            StatusStat(label: 'Uptime', value: '—'),
          ],
        ),
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

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class CommandResultDialog extends StatelessWidget {
  const CommandResultDialog({
    required this.command,
    required this.commandId,
    required this.modeCode,
    required this.source,
    required this.createdBy,
    required this.createdAt,
    required this.deviceStatus,
    this.isIOS = false,
    super.key,
  });

  final String command;
  final String commandId;
  final String modeCode;
  final String source;
  final String createdBy;
  final String createdAt;
  final String deviceStatus;
  final bool isIOS;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultRow(label: 'Command ID', value: commandId),
        _ResultRow(label: 'Mode', value: modeCode),
        _ResultRow(label: 'Source', value: source),
        _ResultRow(label: 'Created by', value: createdBy),
        _ResultRow(label: 'Created at', value: createdAt),
        _ResultRow(label: 'Device status', value: deviceStatus),
        const SizedBox(height: 8),
        const Text(
          'The MQTT bridge will publish this payload to the '
          'Wokwi device on the next tick.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
    if (isIOS) {
      return CupertinoAlertDialog(
        title: Text('Command accepted: $command'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: body,
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF1F7A5B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Command accepted: $command',
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: body,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

enum DangerLevel {
  safe('Safe', Icons.check_circle_outline, Color(0xFF1F7A5B), 'No extra caution needed.'),
  risky('Risky', Icons.warning_amber_rounded, Color(0xFFB26A00),
      'One direction will be blocked from green.'),
  critical('Critical', Icons.dangerous_outlined, Color(0xFFC0392B),
      'All approaches will flash red until cleared by the operator.');

  const DangerLevel(this.label, this.icon, this.color, this.description);

  final String label;
  final IconData icon;
  final Color color;
  final String description;

  static DangerLevel forMode(String modeCode) {
    return switch (modeCode) {
      'EMERGENCY' => DangerLevel.critical,
      'PRIORITY_NS' || 'PRIORITY_EW' => DangerLevel.risky,
      _ => DangerLevel.safe,
    };
  }
}

class DangerousCommandDialog extends StatelessWidget {
  const DangerousCommandDialog({
    required this.modeCode,
    required this.danger,
    this.isIOS = false,
    super.key,
  });

  final String modeCode;
  final DangerLevel danger;
  final bool isIOS;

  String get _impact {
    return switch (modeCode) {
      'PRIORITY_NS' =>
        'North-South will get a forced green while East-West stays red.',
      'PRIORITY_EW' =>
        'East-West will get a forced green while North-South stays red.',
      'EMERGENCY' =>
        'Both directions will lock on flashing red. Traffic will stop '
            'until you switch back to AUTO or NIGHT.',
      _ => danger.description,
    };
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Risk level: ${danger.label}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: danger.color,
          ),
        ),
        const SizedBox(height: 12),
        Text(_impact),
        const SizedBox(height: 12),
        const Text(
          'The Wokwi device will receive the new mode on its next '
          'MQTT tick (~1 second).',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
    if (isIOS) {
      return CupertinoAlertDialog(
        title: Text('Confirm SET_$modeCode'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: content,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send anyway'),
          ),
        ],
      );
    }
    return AlertDialog(
      icon: Icon(danger.icon, color: danger.color, size: 32),
      title: Text('Confirm SET_$modeCode'),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: danger.color,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.send),
          label: const Text('Send anyway'),
        ),
      ],
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

class ApiClient {
  ApiClient(this.baseUrl, {this.maxAttempts = 3});

  final String baseUrl;
  final int maxAttempts;

  Future<Map<String, dynamic>> getJson(String path) => _send('GET', path);

  Future<Map<String, dynamic>> postJson(
          String path, Map<String, dynamic> body) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> putJson(
          String path, Map<String, dynamic> body) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    final encodedBody = body == null ? null : jsonEncode(body);

    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = switch (method) {
          'POST' => await http
              .post(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 5)),
          'PUT' => await http
              .put(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 5)),
          _ => await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 5)),
        };
        // 4xx: client error, do not retry.
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return _decodeOrThrow(response);
        }
        // 2xx: success.
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _decodeOrThrow(response);
        }
        // 5xx or anything else: retryable.
        lastError = ApiException('HTTP ${response.statusCode}');
      } on http.ClientException {
        lastError = ApiException('Không kết nối được API $baseUrl');
      } on TimeoutException {
        lastError = ApiException('API timeout $baseUrl');
      } on FormatException {
        // Bad response payload: do not retry, surface immediately.
        throw ApiException('API trả về dữ liệu không hợp lệ');
      }
      if (attempt < maxAttempts) {
        // Exponential backoff: 300ms, 600ms, 1200ms ...
        final delay = Duration(
            milliseconds: 300 * (1 << (attempt - 1)));
        await Future<void>.delayed(delay);
      }
    }
    throw lastError ?? ApiException('API request failed after $maxAttempts attempts');
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      if (error is Map<String, dynamic> && error['message'] != null) {
        throw ApiException(error['message'].toString());
      }
      throw ApiException('HTTP ${response.statusCode}');
    }
    return decoded;
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DashboardSnapshot {
  DashboardSnapshot({
    required this.status,
    required this.approaches,
    required this.phasePlans,
    required this.commands,
    required this.logs,
    required this.modes,
    required this.deviceStatuses,
  });

  final TrafficStatus status;
  final List<Approach> approaches;
  final List<PhasePlan> phasePlans;
  final List<CommandEntry> commands;
  final List<TrafficLog> logs;
  final List<Map<String, dynamic>> modes;
  final List<Map<String, dynamic>> deviceStatuses;

  factory DashboardSnapshot.empty() => DashboardSnapshot(
        status: TrafficStatus.empty(),
        approaches: [],
        phasePlans: [],
        commands: [],
        logs: [],
        modes: [],
        deviceStatuses: [],
      );

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSnapshot(
      status: TrafficStatus.fromJson(asMap(json['status'])),
      approaches: asList(json['approaches'])
          .map((item) => Approach.fromJson(asMap(item)))
          .toList(),
      phasePlans: asList(json['phasePlans'])
          .map((item) => PhasePlan.fromJson(asMap(item)))
          .toList(),
      commands: asList(json['commands'])
          .map((item) => CommandEntry.fromJson(asMap(item)))
          .toList(),
      logs: asList(json['logs'])
          .map((item) => TrafficLog.fromJson(asMap(item)))
          .toList(),
      modes: asList(json['modes']).map(asMap).toList(),
      deviceStatuses: asList(json['deviceStatuses']).map(asMap).toList(),
    );
  }

  DashboardSnapshot copyWith({TrafficStatus? status}) {
    return DashboardSnapshot(
      status: status ?? this.status,
      approaches: approaches,
      phasePlans: phasePlans,
      commands: commands,
      logs: logs,
      modes: modes,
      deviceStatuses: deviceStatuses,
    );
  }
}

class TrafficStatus {
  TrafficStatus({
    required this.modeCode,
    required this.phaseCode,
    required this.remainingSeconds,
    required this.signals,
  });

  final String modeCode;
  final String phaseCode;
  final int remainingSeconds;
  final List<SignalStatus> signals;

  factory TrafficStatus.empty() => TrafficStatus(
      modeCode: 'AUTO',
      phaseCode: 'NS_GREEN',
      remainingSeconds: 8,
      signals: []);

  factory TrafficStatus.fromJson(Map<String, dynamic> json) {
    return TrafficStatus(
      modeCode: text(json['modeCode'] ?? json['mode_code'], 'AUTO'),
      phaseCode: text(json['phaseCode'] ?? json['phase_code'], 'NS_GREEN'),
      remainingSeconds:
          number(json['remainingSeconds'] ?? json['remaining_seconds'], -1),
      signals: asList(json['signals'])
          .map((item) => SignalStatus.fromJson(asMap(item)))
          .toList(),
    );
  }
}

class SignalStatus {
  SignalStatus(
      {required this.approach, required this.signal, required this.color});

  final String approach;
  final String signal;
  final String color;

  factory SignalStatus.fromJson(Map<String, dynamic> json) {
    return SignalStatus(
      approach: text(json['approach'] ?? json['Approach'], ''),
      signal: text(json['signal'] ?? json['Signal'], ''),
      color: text(json['color'] ?? json['Color'], 'OFF').toUpperCase(),
    );
  }
}

class Approach {
  Approach({
    required this.id,
    required this.code,
    required this.name,
    required this.displayOrder,
    required this.isActive,
    required this.signalCode,
    required this.redPin,
    required this.yellowPin,
    required this.greenPin,
  });

  final int id;
  final String code;
  final String name;
  final int displayOrder;
  final bool isActive;
  final String signalCode;
  final int redPin;
  final int yellowPin;
  final int greenPin;

  factory Approach.fromJson(Map<String, dynamic> json) {
    return Approach(
      id: number(json['id'], 0),
      code: text(json['code'], ''),
      name: text(json['name'], ''),
      displayOrder: number(json['display_order'] ?? json['displayOrder'], 0),
      isActive: boolean(json['is_active'] ?? json['isActive'], true),
      signalCode: text(json['signal_code'] ?? json['signalCode'], ''),
      redPin: number(json['red_pin'] ?? json['redPin'], -1),
      yellowPin: number(json['yellow_pin'] ?? json['yellowPin'], -1),
      greenPin: number(json['green_pin'] ?? json['greenPin'], -1),
    );
  }
}

class PhasePlan {
  PhasePlan(
      {required this.id,
      required this.name,
      required this.isActive,
      required this.steps});

  final int id;
  final String name;
  final bool isActive;
  final List<PhaseStep> steps;

  int get greenSeconds {
    final greenSteps =
        steps.where((step) => step.code.endsWith('_GREEN')).toList();
    return greenSteps.isEmpty ? 10 : greenSteps.first.durationSeconds;
  }

  int get yellowSeconds {
    final yellowSteps =
        steps.where((step) => step.code.endsWith('_YELLOW')).toList();
    return yellowSteps.isEmpty ? 3 : yellowSteps.first.durationSeconds;
  }

  factory PhasePlan.fromJson(Map<String, dynamic> json) {
    return PhasePlan(
      id: number(json['id'], 0),
      name: text(json['name'], 'Phase plan'),
      isActive: boolean(json['is_active'] ?? json['isActive'], false),
      steps: asList(json['steps'])
          .map((item) => PhaseStep.fromJson(asMap(item)))
          .toList(),
    );
  }
}

class PhaseStep {
  PhaseStep({required this.code, required this.durationSeconds});

  final String code;
  final int durationSeconds;

  factory PhaseStep.fromJson(Map<String, dynamic> json) {
    return PhaseStep(
      code: text(json['code'], ''),
      durationSeconds:
          number(json['duration_seconds'] ?? json['durationSeconds'], 0),
    );
  }
}

class CommandEntry {
  CommandEntry({
    required this.command,
    required this.source,
    required this.status,
    required this.createdAt,
  });

  final String command;
  final String source;
  final String status;
  final String createdAt;

  factory CommandEntry.fromJson(Map<String, dynamic> json) {
    return CommandEntry(
      command: text(json['command'], ''),
      source: text(json['source'], ''),
      status: text(json['device_status'] ?? json['status'], ''),
      createdAt: compactTime(json['created_at']),
    );
  }
}

class TrafficLog {
  TrafficLog({
    required this.modeCode,
    required this.phaseCode,
    required this.remainingSeconds,
    required this.createdAt,
  });

  final String modeCode;
  final String phaseCode;
  final int remainingSeconds;
  final String createdAt;

  factory TrafficLog.fromJson(Map<String, dynamic> json) {
    return TrafficLog(
      modeCode: text(json['mode_code'], ''),
      phaseCode: text(json['phase_code'], ''),
      remainingSeconds: number(json['remaining_seconds'], -1),
      createdAt: compactTime(json['created_at']),
    );
  }
}

const defaultApiBase =
    kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

const String _apiBasePrefsKey = 'iot_traffic_light.api_base_url';
const String _skipConfirmPrefsKey = 'iot_traffic_light.skip_danger_confirm';

class SettingsStore {
  SettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsStore._(prefs);
  }

  String? readApiBase() {
    final raw = _prefs.getString(_apiBasePrefsKey);
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> writeApiBase(String value) async {
    final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) {
      await _prefs.remove(_apiBasePrefsKey);
      return;
    }
    await _prefs.setString(_apiBasePrefsKey, trimmed);
  }

  bool readSkipConfirm() => _prefs.getBool(_skipConfirmPrefsKey) ?? false;

  Future<void> writeSkipConfirm(bool value) async {
    if (value) {
      await _prefs.setBool(_skipConfirmPrefsKey, true);
    } else {
      await _prefs.remove(_skipConfirmPrefsKey);
    }
  }
}

String modeLabel(String modeCode) {
  return switch (modeCode) {
    'PRIORITY_NS' => 'PRIORITY NS',
    'PRIORITY_EW' => 'PRIORITY EW',
    _ => modeCode,
  };
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<dynamic> asList(Object? value) => value is List ? value : <dynamic>[];

String text(Object? value, String fallback) {
  final result = value?.toString();
  return result == null || result.isEmpty ? fallback : result;
}

int number(Object? value, int fallback) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool boolean(Object? value, bool fallback) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final normalized = value?.toString().toLowerCase();
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  return fallback;
}

String compactTime(Object? value) {
  final raw = value?.toString() ?? '';
  return raw.replaceFirst('T', ' ').split('.').first;
}
