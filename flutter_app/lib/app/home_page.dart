import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../data/dashboard_snapshot.dart';
import '../views/control_view.dart';
import '../views/history_view.dart';
import '../views/live_status_view.dart';
import '../views/mobile_settings_view.dart';
import '../views/schedule_view.dart';
import '../widgets/atoms.dart';
import '../widgets/dialogs.dart';

class TrafficHomePage extends StatefulWidget {
  const TrafficHomePage({required this.messengerKey, super.key});

  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  State<TrafficHomePage> createState() => _TrafficHomePageState();
}

class _TrafficHomePageState extends State<TrafficHomePage> {
  static const int _defaultDashboardPollTicks = 10;
  static const int _dataHeavyDashboardPollTicks = 4;
  static const List<String> _navPages = <String>[
    'control',
    'live',
    'schedule',
    'logs',
    'settings',
  ];

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
  bool _statusPollInFlight = false;
  bool _dashboardRefreshInFlight = false;
  int _pollTick = 0;

  bool isRunning(String key) => _runningActions.contains(key);
  bool get anyLoading => _runningActions.isNotEmpty;
  String get _deviceId {
    if (dashboard.deviceStatuses.isEmpty) {
      return 'TrafficLight-01';
    }
    return text(dashboard.deviceStatuses.first['device_id'], 'TrafficLight-01');
  }

  void _setRunning(String key, bool value) {
    if (!mounted) {
      return;
    }
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
    pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_pollOnce()),
    );
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
    if (!mounted) {
      return;
    }
    await refreshDashboard();
  }

  int get _dashboardPollTicks {
    return switch (selectedPage) {
      'logs' || 'settings' => _dataHeavyDashboardPollTicks,
      _ => _defaultDashboardPollTicks,
    };
  }

  Future<void> _pollOnce() async {
    if (!online ||
        anyLoading ||
        _statusPollInFlight ||
        _dashboardRefreshInFlight) {
      return;
    }
    _pollTick += 1;
    if (_pollTick % _dashboardPollTicks == 0) {
      await _refreshDashboardSilently();
      return;
    }
    await refreshStatusOnly();
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
    if (_dashboardRefreshInFlight && force) {
      while (_dashboardRefreshInFlight && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    if (!mounted) {
      return;
    }
    if (_dashboardRefreshInFlight) {
      return;
    }
    if (isRunning('refresh') && !force) {
      return;
    }

    _dashboardRefreshInFlight = true;
    _setRunning('refresh', true);

    try {
      final data = await api.getJson('/api/intersections/1/dashboard');
      if (!mounted) return;
      setState(() {
        dashboard = DashboardSnapshot.fromJson(requireDataMap(data));
        online = true;
        _lastSnapshotAt = DateTime.now();
        _pollTick = 0;
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
      _dashboardRefreshInFlight = false;
      if (mounted) {
        _setRunning('refresh', false);
      }
    }
  }

  Future<void> _refreshDashboardSilently() async {
    if (_dashboardRefreshInFlight || anyLoading) {
      return;
    }
    _dashboardRefreshInFlight = true;
    try {
      final data = await api.getJson('/api/intersections/1/dashboard');
      if (!mounted) return;
      setState(() {
        dashboard = DashboardSnapshot.fromJson(requireDataMap(data));
        online = true;
        _lastSnapshotAt = DateTime.now();
        _pollTick = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        online = false;
      });
    } finally {
      _dashboardRefreshInFlight = false;
    }
  }

  Future<void> refreshStatusOnly() async {
    if (!online || _statusPollInFlight || _dashboardRefreshInFlight) {
      return;
    }
    // Skip the silent poll while any user-initiated action is running so
    // we do not pile up parallel GET /status calls.
    if (anyLoading) {
      return;
    }

    _statusPollInFlight = true;
    try {
      final data = await api.getJson('/api/intersections/1/status');
      if (!mounted) return;
      setState(() {
        dashboard = dashboard.copyWith(
          status: TrafficStatus.fromJson(requireDataMap(data)),
        );
        _lastSnapshotAt = DateTime.now();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          online = false;
        });
      }
    } finally {
      _statusPollInFlight = false;
    }
  }

  Future<void> sendCommand(String modeCode) async {
    final key = 'cmd:$modeCode';
    if (_runningActions.any((action) => action.startsWith('cmd:'))) {
      return;
    }

    final danger = DangerLevel.forMode(modeCode);
    if (danger != DangerLevel.safe && _requireConfirm(danger)) {
      final confirmed = await _showDangerConfirmDialog(modeCode, danger);
      if (confirmed != true) {
        return;
      }
      if (!mounted) {
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

      final result = requireDataMap(data);
      final commandTrafficStatus = asMap(result['trafficStatus']);
      await refreshDashboard(force: true);
      if (!mounted) return;
      setState(() {
        online = true;
      });
      final latestCommand = _latestCommandEntry(result) ??
          CommandEntry.fallback(
            command: result['command']?.toString() ?? 'SET_$modeCode',
            modeCode: text(commandTrafficStatus['modeCode'], modeCode),
            source: 'flutter',
            createdBy: 'operator',
          );
      _showCommandResultDialog(latestCommand);
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

  CommandEntry? _latestCommandEntry(Map<String, dynamic> result) {
    if (dashboard.commands.isEmpty) {
      return null;
    }
    final createdCommand = result['command']?.toString();
    if (createdCommand == null || createdCommand.isEmpty) {
      return dashboard.commands.first;
    }
    for (final entry in dashboard.commands) {
      if (entry.command == createdCommand) {
        return entry;
      }
    }
    return dashboard.commands.first;
  }

  Future<void> _showCommandResultDialog(CommandEntry entry) async {
    final messenger = _messengerKey.currentState;
    if (messenger == null) {
      return;
    }
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    Future<void> Function() showIt = isIOS
        ? () => showCupertinoDialog<void>(
              context: messenger.context,
              builder: (ctx) => CommandResultDialog(
                command: entry.command,
                commandId: entry.id <= 0 ? '-' : entry.id.toString(),
                modeCode: entry.modeCode.isEmpty ? '-' : entry.modeCode,
                source: entry.source.isEmpty ? '-' : entry.source,
                createdBy: entry.createdBy.isEmpty ? '-' : entry.createdBy,
                createdAt: entry.createdAt,
                commandStatus: entry.commandStatus.isEmpty
                    ? 'success'
                    : entry.commandStatus,
                deviceStatus:
                    entry.deviceStatus.isEmpty ? 'queued' : entry.deviceStatus,
                deviceMessage: entry.deviceMessage,
                mqttTopic: entry.mqttTopic,
                publishedAt: entry.publishedAt,
                acknowledgedAt: entry.acknowledgedAt,
                isIOS: true,
              ),
            )
        : () => showDialog<void>(
              context: messenger.context,
              builder: (ctx) => CommandResultDialog(
                command: entry.command,
                commandId: entry.id <= 0 ? '-' : entry.id.toString(),
                modeCode: entry.modeCode.isEmpty ? '-' : entry.modeCode,
                source: entry.source.isEmpty ? '-' : entry.source,
                createdBy: entry.createdBy.isEmpty ? '-' : entry.createdBy,
                createdAt: entry.createdAt,
                commandStatus: entry.commandStatus.isEmpty
                    ? 'success'
                    : entry.commandStatus,
                deviceStatus:
                    entry.deviceStatus.isEmpty ? 'queued' : entry.deviceStatus,
                deviceMessage: entry.deviceMessage,
                mqttTopic: entry.mqttTopic,
                publishedAt: entry.publishedAt,
                acknowledgedAt: entry.acknowledgedAt,
              ),
            );

    await showIt();
  }

  Future<void> updatePhasePlan(
      PhasePlan plan, int greenSeconds, int yellowSeconds) async {
    final key = 'plan:update:${plan.id}';
    if (isRunning(key) || isRunning('plan:activate:${plan.id}')) {
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
      _showSnack(SnackKind.success, 'Đã cập nhật chu kỳ ${plan.name}');
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
    if (isRunning(key) || isRunning('plan:update:${plan.id}')) {
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
      _showSnack(SnackKind.success, 'Đã kích hoạt chu kỳ ${plan.name}');
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
      final value = normalizeApiBase(apiController.text);
      if (value == null) {
        _showSnack(
          SnackKind.error,
          'Địa chỉ API phải bắt đầu bằng http:// hoặc https://',
        );
        return;
      }

      setState(() {
        apiController.text = value;
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

      await refreshDashboard(force: true);
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

  @override
  Widget build(BuildContext context) {
    final content = switch (selectedPage) {
      'control' => ControlView(
          snapshot: dashboard,
          currentMode: dashboard.status.modeCode,
          online: online,
          isRunning: isRunning,
          onCommand: sendCommand,
        ),
      'live' => LiveStatusView(
          snapshot: dashboard,
          lastSnapshotAt: _lastSnapshotAt,
          online: online,
        ),
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
          onRefresh: () => refreshDashboard(force: true),
          onToggleSkipConfirm: toggleSkipConfirm,
        ),
      _ => ControlView(
          snapshot: dashboard,
          currentMode: dashboard.status.modeCode,
          online: online,
          isRunning: isRunning,
          onCommand: sendCommand,
        ),
    };

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS uses CupertinoTabScaffold; the body is the same content tree
      // (AppHeader + DeviceBadge + AnimatedSwitcher), wrapped per-tab in
      // CupertinoTabView so each tab keeps its own Navigator stack.
      return Scaffold(
        backgroundColor: AppColors.background,
        body: CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            backgroundColor: AppColors.surface,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.muted,
            currentIndex: _navIndex(selectedPage),
            onTap: (index) {
              setState(() {
                selectedPage = _navPages[index];
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
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Nhật ký',
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
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        children: [
                          AppHeader(
                            title: _pageTitle(selectedPage),
                            online: online,
                            loading: anyLoading,
                            onRefresh: () => refreshDashboard(force: true),
                            showMenu: false,
                          ),
                          const SizedBox(height: 8),
                          DeviceBadge(
                            deviceId: _deviceId,
                            online: online,
                            apiBase: api.baseUrl,
                          ),
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
        ),
      );
    }
    return Scaffold(
      drawer: AppDrawer(
        deviceId: _deviceId,
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              AppHeader(
                title: _pageTitle(selectedPage),
                online: online,
                loading: anyLoading,
                onRefresh: () => refreshDashboard(force: true),
              ),
              const SizedBox(height: 8),
              DeviceBadge(
                deviceId: _deviceId,
                online: online,
                apiBase: api.baseUrl,
              ),
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
          selectedIndex: _navIndex(selectedPage),
          onDestinationSelected: (index) {
            setState(() {
              selectedPage = _navPages[index];
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
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Nhật ký',
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

  int _navIndex(String page) {
    final index = _navPages.indexOf(page);
    return index < 0 ? 0 : index;
  }

  String _pageTitle(String page) {
    return switch (page) {
      'control' => 'Điều khiển',
      'live' => 'Trạng thái trực tiếp',
      'schedule' => 'Chu kỳ AUTO',
      'logs' => 'Nhật ký thiết bị',
      'settings' => 'Cài đặt & Trạng thái',
      _ => 'Điều khiển',
    };
  }
}
