import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app/colors.dart';
import 'data/dashboard_snapshot.dart';

void main() {
  runApp(const TrafficOperatorApp());
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

