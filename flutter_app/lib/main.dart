import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TrafficOperatorApp());
}

class TrafficOperatorApp extends StatelessWidget {
  const TrafficOperatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IoT Traffic Light',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F7A5B),
          brightness: Brightness.light,
        ).copyWith(surface: Colors.white),
        scaffoldBackgroundColor: const Color(0xFFF3F5F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFDDE3DC)),
          ),
        ),
      ),
      home: const TrafficHomePage(),
    );
  }
}

class TrafficHomePage extends StatefulWidget {
  const TrafficHomePage({super.key});

  @override
  State<TrafficHomePage> createState() => _TrafficHomePageState();
}

class _TrafficHomePageState extends State<TrafficHomePage> {
  final TextEditingController apiController =
      TextEditingController(text: defaultApiBase);
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  late ApiClient api = ApiClient(defaultApiBase);
  SettingsStore? _settings;
  Timer? pollTimer;

  DashboardSnapshot dashboard = DashboardSnapshot.empty();
  bool loading = false;
  bool online = false;
  String selectedPage = 'dashboard';

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
      if (savedBase != null && mounted) {
        setState(() {
          api = ApiClient(savedBase);
          apiController.text = savedBase;
        });
      }
      _settings = store;
    } catch (error) {
      // Persistent settings are optional; the app still works with
      // the default API URL if SharedPreferences is unavailable.
    }
    await refreshDashboard();
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    apiController.dispose();
    super.dispose();
  }

  Future<void> refreshDashboard({bool force = false}) async {
    if (loading && !force) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final data = await api.getJson('/api/intersections/1/dashboard');
      if (!mounted) return;
      setState(() {
        dashboard =
            DashboardSnapshot.fromJson(data['data'] as Map<String, dynamic>);
        online = true;
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
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> refreshStatusOnly() async {
    if (!online || loading) {
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
    setState(() {
      loading = true;
    });

    try {
      final data = await api.postJson('/api/intersections/1/commands', {
        'command': 'SET_$modeCode',
        'modeCode': modeCode,
        'source': 'flutter',
        'createdBy': 'operator',
      });

      final result = data['data'] as Map<String, dynamic>;
      await refreshDashboard(force: true);
      setState(() {
        online = true;
      });
      _showSnack(SnackKind.success, 'Da gui ${result['command']}');
    } catch (error) {
      _showSnack(SnackKind.error, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> updatePhasePlan(
      PhasePlan plan, int greenSeconds, int yellowSeconds) async {
    setState(() {
      loading = true;
    });

    try {
      await api.putJson('/api/phase-plans/${plan.id}', {
        'greenSeconds': greenSeconds,
        'yellowSeconds': yellowSeconds,
      });
      await refreshDashboard(force: true);
      setState(() {
        online = true;
      });
      _showSnack(SnackKind.success, 'Da cap nhat phase plan ${plan.name}');
    } catch (error) {
      _showSnack(SnackKind.error, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> activatePhasePlan(PhasePlan plan) async {
    setState(() {
      loading = true;
    });

    try {
      await api.postJson('/api/phase-plans/${plan.id}/activate', {});
      await refreshDashboard(force: true);
      setState(() {
        online = true;
      });
      _showSnack(SnackKind.success, 'Da kich hoat phase plan ${plan.name}');
    } catch (error) {
      _showSnack(SnackKind.error, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> updateApproach(Approach approach, bool isActive) async {
    setState(() {
      loading = true;
    });

    try {
      await api.putJson('/api/approaches/${approach.id}', {
        'name': approach.name,
        'displayOrder': approach.displayOrder,
        'isActive': isActive,
      });
      await refreshDashboard(force: true);
      setState(() {
        online = true;
      });
      _showSnack(
        SnackKind.success,
        '${approach.code} da ${isActive ? 'bat' : 'tat'} tren backend',
      );
    } catch (error) {
      _showSnack(SnackKind.error, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> applyApiBase() async {
    final value = apiController.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (value.isEmpty) {
      _showSnack(SnackKind.error, 'API URL khong duoc de trong');
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
        _showSnack(SnackKind.info, 'Khong luu duoc API URL local');
      }
    }

    await refreshDashboard();
    if (online) {
      _showSnack(SnackKind.success, 'Da ket noi $value');
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
    if (loading) {
      return 'Dang dong bo backend ...';
    }
    return online ? 'Backend san sang' : 'Mat ket noi backend';
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (selectedPage) {
      'dashboard' => DashboardView(snapshot: dashboard),
      'control' => ControlView(
          currentMode: dashboard.status.modeCode,
          loading: loading,
          onCommand: sendCommand,
        ),
      'manage' => ManageView(
          phasePlans: dashboard.phasePlans,
          approaches: dashboard.approaches,
          loading: loading,
          onUpdatePlan: updatePhasePlan,
          onActivatePlan: activatePhasePlan,
          onUpdateApproach: updateApproach,
        ),
      'history' =>
        HistoryView(commands: dashboard.commands, logs: dashboard.logs),
      'settings' => SettingsView(
          controller: apiController,
          online: online,
          apiBase: api.baseUrl,
          deviceStatuses: dashboard.deviceStatuses,
          onApply: applyApiBase,
          onRefresh: refreshDashboard,
        ),
      _ => DashboardView(snapshot: dashboard),
    };

    return Scaffold(
      key: _messengerKey,
      appBar: AppBar(
        title: const Text('IoT Traffic Light'),
        actions: [
          ConnectionBadge(online: online, loading: loading),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshDashboard,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StatusBanner(online: online, status: connectionLabel),
                      const SizedBox(height: 12),
                      content,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: ['dashboard', 'control', 'manage', 'history', 'settings']
            .indexOf(selectedPage),
        onDestinationSelected: (index) {
          setState(() {
            selectedPage = [
              'dashboard',
              'control',
              'manage',
              'history',
              'settings'
            ][index];
          });
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: 'Control'),
          NavigationDestination(
              icon: Icon(Icons.account_tree_outlined),
              selectedIcon: Icon(Icons.account_tree),
              label: 'Manage'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
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
    required this.currentMode,
    required this.loading,
    required this.onCommand,
    super.key,
  });

  final String currentMode;
  final bool loading;
  final Future<void> Function(String modeCode) onCommand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ControlButton(
          modeCode: 'AUTO',
          label: 'AUTO',
          icon: Icons.autorenew,
          active: currentMode == 'AUTO',
          loading: loading,
          onPressed: onCommand,
        ),
        ControlButton(
          modeCode: 'NIGHT',
          label: 'NIGHT',
          icon: Icons.nightlight_round,
          active: currentMode == 'NIGHT',
          loading: loading,
          onPressed: onCommand,
        ),
        ControlButton(
          modeCode: 'PRIORITY_NS',
          label: 'PRIORITY NS',
          icon: Icons.swap_vert,
          active: currentMode == 'PRIORITY_NS',
          loading: loading,
          onPressed: onCommand,
        ),
        ControlButton(
          modeCode: 'PRIORITY_EW',
          label: 'PRIORITY EW',
          icon: Icons.swap_horiz,
          active: currentMode == 'PRIORITY_EW',
          loading: loading,
          onPressed: onCommand,
        ),
        ControlButton(
          modeCode: 'EMERGENCY',
          label: 'EMERGENCY',
          icon: Icons.emergency,
          active: currentMode == 'EMERGENCY',
          loading: loading,
          danger: true,
          onPressed: onCommand,
        ),
      ],
    );
  }
}

enum ManageSection { phasePlans, roads }

class ManageView extends StatefulWidget {
  const ManageView({
    required this.phasePlans,
    required this.approaches,
    required this.loading,
    required this.onUpdatePlan,
    required this.onActivatePlan,
    required this.onUpdateApproach,
    super.key,
  });

  final List<PhasePlan> phasePlans;
  final List<Approach> approaches;
  final bool loading;
  final Future<void> Function(
      PhasePlan plan, int greenSeconds, int yellowSeconds) onUpdatePlan;
  final Future<void> Function(PhasePlan plan) onActivatePlan;
  final Future<void> Function(Approach approach, bool isActive)
      onUpdateApproach;

  @override
  State<ManageView> createState() => _ManageViewState();
}

class _ManageViewState extends State<ManageView> {
  ManageSection selected = ManageSection.phasePlans;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ManageSection>(
          segments: const [
            ButtonSegment(
              value: ManageSection.phasePlans,
              icon: Icon(Icons.timer_outlined),
              label: Text('Phase plan'),
            ),
            ButtonSegment(
              value: ManageSection.roads,
              icon: Icon(Icons.alt_route),
              label: Text('Roads'),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (value) {
            setState(() {
              selected = value.first;
            });
          },
        ),
        const SizedBox(height: 12),
        if (selected == ManageSection.phasePlans)
          PhasePlanEditor(
            phasePlans: widget.phasePlans,
            loading: widget.loading,
            onUpdate: widget.onUpdatePlan,
            onActivate: widget.onActivatePlan,
          )
        else
          RoadsView(
            approaches: widget.approaches,
            loading: widget.loading,
            onUpdate: widget.onUpdateApproach,
          ),
      ],
    );
  }
}

class PhasePlanEditor extends StatelessWidget {
  const PhasePlanEditor({
    required this.phasePlans,
    required this.loading,
    required this.onUpdate,
    required this.onActivate,
    super.key,
  });

  final List<PhasePlan> phasePlans;
  final bool loading;
  final Future<void> Function(
      PhasePlan plan, int greenSeconds, int yellowSeconds) onUpdate;
  final Future<void> Function(PhasePlan plan) onActivate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Phase plan configuration',
      child: phasePlans.isEmpty
          ? const EmptyState(text: 'Chua co phase plan')
          : Column(
              children: phasePlans
                  .map(
                    (plan) => PhasePlanEditorTile(
                      plan: plan,
                      loading: loading,
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
    required this.loading,
    required this.onUpdate,
    required this.onActivate,
    super.key,
  });

  final PhasePlan plan;
  final bool loading;
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
                      enabled: !widget.loading,
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
                      enabled: !widget.loading,
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
                      onPressed: widget.loading
                          ? null
                          : () => widget.onActivate(widget.plan),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Activate'),
                    ),
                  FilledButton.icon(
                    onPressed: widget.loading
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
                    icon: const Icon(Icons.save),
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
    required this.loading,
    required this.onUpdate,
    super.key,
  });

  final List<Approach> approaches;
  final bool loading;
  final Future<void> Function(Approach approach, bool isActive) onUpdate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Road approaches and signal heads',
      child: approaches.isEmpty
          ? const EmptyState(text: 'Chua co approach')
          : Column(
              children: approaches
                  .map(
                    (approach) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.traffic),
                      title: Text('${approach.code} - ${approach.name}'),
                      subtitle: Text(
                        '${approach.signalCode} | pins '
                        'R${approach.redPin} Y${approach.yellowPin} '
                        'G${approach.greenPin}',
                      ),
                      value: approach.isActive,
                      onChanged:
                          loading ? null : (value) => onUpdate(approach, value),
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
              ? const EmptyState(text: 'Chua co command')
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
              ? const EmptyState(text: 'Chua co log')
              : Column(
                  children: logs.map((log) => LogTile(log: log)).toList(),
                ),
        ),
      ],
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({
    required this.controller,
    required this.online,
    required this.apiBase,
    required this.deviceStatuses,
    required this.onApply,
    required this.onRefresh,
    super.key,
  });

  final TextEditingController controller;
  final bool online;
  final String apiBase;
  final List<Map<String, dynamic>> deviceStatuses;
  final Future<void> Function() onApply;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Backend connection',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
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
                  onPressed: onApply,
                  icon: const Icon(Icons.save),
                  label: const Text('Apply'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
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
          Text('ESP32 devices', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (deviceStatuses.isEmpty)
            const Text('Chua nhan heartbeat/status tu Wokwi')
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
        icon: Icon(icon),
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
          ? const EmptyState(text: 'Chua co phase plan')
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
  ApiClient(this.baseUrl);

  final String baseUrl;

  Future<Map<String, dynamic>> getJson(String path) => _send('GET', path);

  Future<Map<String, dynamic>> postJson(
          String path, Map<String, dynamic> body) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> putJson(
          String path, Map<String, dynamic> body) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = <String, String>{'Accept': 'application/json'};
      if (body != null) {
        headers['Content-Type'] = 'application/json';
      }

      final response = switch (method) {
        'POST' => await http
            .post(uri,
                headers: headers, body: body == null ? null : jsonEncode(body))
            .timeout(const Duration(seconds: 5)),
        'PUT' => await http
            .put(uri,
                headers: headers, body: body == null ? null : jsonEncode(body))
            .timeout(const Duration(seconds: 5)),
        _ => await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 5)),
      };
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
    } on http.ClientException {
      throw ApiException('Khong ket noi duoc API $baseUrl');
    } on TimeoutException {
      throw ApiException('API timeout $baseUrl');
    } on FormatException {
      throw ApiException('API tra ve du lieu khong hop le');
    }
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
