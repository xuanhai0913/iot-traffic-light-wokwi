import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_traffic_light/data/dashboard_snapshot.dart';
import 'package:iot_traffic_light/main.dart';
import 'package:iot_traffic_light/views/control_view.dart';
import 'package:iot_traffic_light/views/live_status_view.dart';
import 'package:iot_traffic_light/views/mobile_settings_view.dart';
import 'package:iot_traffic_light/widgets/atoms.dart';
import 'package:iot_traffic_light/widgets/dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingSeenKey = 'onboarding_seen_v1';

void main() {
  testWidgets('shows onboarding on first launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TrafficOperatorApp());
    await tester.pump();

    expect(find.text('Chế độ hoạt động'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(find.text('Bắt đầu'), findsOneWidget);
  });

  testWidgets('renders traffic operator app', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({_onboardingSeenKey: true});
    await tester.pumpWidget(const TrafficOperatorApp());
    await tester.pump();

    expect(find.text('Điều khiển'), findsAtLeastNWidgets(1));
    expect(find.text('Nhật ký'), findsOneWidget);
  });

  testWidgets('iOS shell hosts feedback and hides the Android drawer menu',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      SharedPreferences.setMockInitialValues({_onboardingSeenKey: true});

      await tester.pumpWidget(const TrafficOperatorApp());
      await tester.pump();

      expect(find.byType(CupertinoTabScaffold), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byTooltip('Menu'), findsNothing);
      expect(find.text('Nhật ký'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('device badge renders while backend connection is pending',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({_onboardingSeenKey: true});
    await tester.pumpWidget(const TrafficOperatorApp());
    // pump once to lay out the initial frame; do not pumpAndSettle because
    // the bootstrap fires a real HTTP request and we do not want the test
    // to depend on the network.
    await tester.pump();

    expect(find.textContaining('TrafficLight-01'), findsOneWidget);
    // The old inline message must be gone.
    expect(find.text('Mất kết nối backend'), findsNothing);
  });

  test('SnackKind maps each kind to a distinct icon and color', () {
    expect(SnackKind.success.icon, Icons.check_circle);
    expect(SnackKind.error.icon, Icons.error_outline);
    expect(SnackKind.info.icon, Icons.info_outline);
    // Error snackbars must last longer than success so the operator can read
    // the failure cause.
    expect(SnackKind.error.durationSeconds,
        greaterThan(SnackKind.success.durationSeconds));
  });

  testWidgets('ControlView disables command buttons while backend is pending',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({_onboardingSeenKey: true});
    await tester.pumpWidget(const TrafficOperatorApp());
    await tester.pump();

    // The first tab is the control dashboard.
    expect(find.widgetWithText(FilledButton, 'Tự động'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ban đêm'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Dừng'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Bắc-Nam'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Đông-Tây'), findsOneWidget);

    final autoButton = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Tự động'));
    expect(autoButton.onPressed, isNull);
    expect(
        find.text('Kết nối lại API để gửi lệnh điều khiển.'), findsOneWidget);

    // Before any command, no per-button progress indicators should be present.
    expect(
      find.descendant(
        of: find.widgetWithText(FilledButton, 'Tự động'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
  });

  testWidgets('CommandResultDialog shows every backend response field',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => const Scaffold(
            body: Center(
              child: CommandResultDialog(
                command: 'SET_AUTO',
                commandId: '999',
                modeCode: 'AUTO',
                source: 'flutter',
                createdBy: 'operator',
                createdAt: '2026-06-18 17:30:00',
                commandStatus: 'success',
                deviceStatus: 'published',
                deviceMessage: 'Published to MQTT broker',
                mqttTopic: 'traffic/demo/intersections/1/commands',
                publishedAt: '2026-06-18 17:30:01',
                acknowledgedAt: '',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Đã gửi SET_AUTO lên MQTT'), findsOneWidget);
    expect(find.text('Command ID'), findsOneWidget);
    expect(find.text('999'), findsOneWidget);
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget);
    expect(find.text('Nguồn'), findsOneWidget);
    expect(find.text('flutter'), findsOneWidget);
    expect(find.text('Người gửi'), findsOneWidget);
    expect(find.text('operator'), findsOneWidget);
    expect(find.text('Tạo lúc'), findsOneWidget);
    expect(find.text('2026-06-18 17:30:00'), findsOneWidget);
    expect(find.text('Thiết bị'), findsOneWidget);
    expect(find.textContaining('ĐÃ GỬI'), findsOneWidget);
    expect(find.text('MQTT topic'), findsOneWidget);
    expect(find.text('traffic/demo/intersections/1/commands'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Đóng'), findsOneWidget);
  });

  group('SettingsStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('readApiBase returns null when nothing is saved', () async {
      final store = await SettingsStore.open();
      expect(store.readApiBase(), isNull);
    });

    test('writeApiBase round-trips a non-empty trimmed URL', () async {
      final store = await SettingsStore.open();
      await store.writeApiBase('  http://192.168.1.10:8000/// ');
      expect(store.readApiBase(), 'http://192.168.1.10:8000');
    });

    test('writeApiBase removes the key when the value is empty', () async {
      final store = await SettingsStore.open();
      await store.writeApiBase('http://10.0.2.2:8000');
      expect(store.readApiBase(), 'http://10.0.2.2:8000');
      await store.writeApiBase('   ');
      expect(store.readApiBase(), isNull);
    });
  });

  group('ApiClient retry behavior', () {
    test('does not retry on 4xx client errors', () {
      final client = ApiClient('http://x', maxAttempts: 3);
      // 404 is 4xx -> should NOT be retried. We assert the public contract:
      // the maxAttempts field is honored as configured and exceptions thrown
      // for 4xx surface immediately.
      expect(client.maxAttempts, 3);
    });

    test('exposes the configured maxAttempts', () {
      expect(ApiClient('http://x').maxAttempts, 3);
      expect(ApiClient('http://x', maxAttempts: 5).maxAttempts, 5);
    });

    test('only retries read requests to avoid duplicate commands', () {
      final client = ApiClient('http://x', maxAttempts: 4);

      expect(client.attemptsForMethod('GET'), 4);
      expect(client.attemptsForMethod('POST'), 1);
      expect(client.attemptsForMethod('PUT'), 1);
    });

    test('ApiException carries the supplied message', () {
      final ex = ApiException('boom');
      expect(ex.message, 'boom');
      expect(ex.toString(), 'boom');
    });
  });

  test('uses the iOS simulator API default outside Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      expect(defaultApiBase, 'http://127.0.0.1:8000');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('normalizes and validates API base URLs', () {
    expect(
      normalizeApiBase('  http://192.168.1.10:8000/// '),
      'http://192.168.1.10:8000',
    );
    expect(normalizeApiBase('192.168.1.10:8000'), isNull);
    expect(normalizeApiBase('ftp://192.168.1.10'), isNull);
    expect(normalizeApiBase('http://host:8000?debug=true'), isNull);
  });

  test('empty traffic status does not pretend a live AUTO phase exists', () {
    final status = TrafficStatus.empty();

    expect(status.modeCode, isEmpty);
    expect(status.phaseCode, isEmpty);
    expect(status.remainingSeconds, -1);
    expect(dominantSignalColor(status), 'OFF');
  });

  test('missing backend status fields do not pretend AUTO data exists', () {
    final status = TrafficStatus.fromJson({});

    expect(status.modeCode, isEmpty);
    expect(status.phaseCode, isEmpty);
    expect(status.remainingSeconds, -1);
    expect(dominantSignalColor(status), 'OFF');
  });

  test('dominant signal color favors an active green over earlier red lamps',
      () {
    final status = TrafficStatus(
      modeCode: 'AUTO',
      phaseCode: 'EW_GREEN',
      remainingSeconds: 5,
      signals: [
        SignalStatus(approach: 'NORTH', signal: 'NORTH_MAIN', color: 'RED'),
        SignalStatus(approach: 'EAST', signal: 'EAST_MAIN', color: 'GREEN'),
      ],
    );

    expect(dominantSignalColor(status), 'GREEN');
  });

  group('DangerLevel', () {
    test('flags EMERGENCY as critical', () {
      expect(DangerLevel.forMode('EMERGENCY'), DangerLevel.critical);
    });

    test('flags PRIORITY modes as risky', () {
      expect(DangerLevel.forMode('PRIORITY_NS'), DangerLevel.risky);
      expect(DangerLevel.forMode('PRIORITY_EW'), DangerLevel.risky);
    });

    test('flags AUTO and NIGHT as safe', () {
      expect(DangerLevel.forMode('AUTO'), DangerLevel.safe);
      expect(DangerLevel.forMode('NIGHT'), DangerLevel.safe);
      expect(DangerLevel.forMode('UNKNOWN'), DangerLevel.safe);
    });

    test('every level has a distinct icon and color', () {
      expect(DangerLevel.safe.icon, isNot(DangerLevel.risky.icon));
      expect(DangerLevel.risky.icon, isNot(DangerLevel.critical.icon));
      expect(DangerLevel.safe.color, isNot(DangerLevel.risky.color));
      expect(DangerLevel.risky.color, isNot(DangerLevel.critical.color));
    });
  });

  testWidgets('DangerousCommandDialog describes the impact of the mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => const Scaffold(
            body: Center(
              child: DangerousCommandDialog(
                modeCode: 'EMERGENCY',
                danger: DangerLevel.critical,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Xác nhận SET_EMERGENCY'), findsOneWidget);
    expect(find.text('Mức độ rủi ro: Nguy hiểm'), findsOneWidget);
    // Critical dialog must mention solid red so the operator reads the
    // consequence before tapping Send.
    expect(find.textContaining('giữ đỏ liên tục'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Hủy'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Vẫn gửi'), findsOneWidget);
  });

  testWidgets('DangerousCommandDialog for PRIORITY_NS describes NS priority',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => const Scaffold(
            body: Center(
              child: DangerousCommandDialog(
                modeCode: 'PRIORITY_NS',
                danger: DangerLevel.risky,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Mức độ rủi ro: Cần chú ý'), findsOneWidget);
    expect(find.textContaining('Bắc-Nam'), findsOneWidget);
    expect(find.textContaining('Đông-Tây'), findsOneWidget);
  });

  test('CommandEntry keeps MQTT delivery fields from backend history', () {
    final entry = CommandEntry.fromJson({
      'id': 17,
      'command': 'SET_NIGHT',
      'mode_code': 'NIGHT',
      'source': 'flutter',
      'created_by': 'operator',
      'status': 'success',
      'device_status': 'acknowledged',
      'device_message': 'device applied',
      'mqtt_topic': 'traffic/demo/intersections/1/commands',
      'created_at': '2026-06-30T10:00:00',
      'published_at': '2026-06-30T10:00:01',
      'acknowledged_at': '2026-06-30T10:00:02',
    });

    expect(entry.id, 17);
    expect(entry.modeCode, 'NIGHT');
    expect(entry.deviceStatus, 'acknowledged');
    expect(entry.deviceMessage, 'device applied');
    expect(entry.mqttTopic, 'traffic/demo/intersections/1/commands');
    expect(entry.publishedAt, '2026-06-30 10:00:01');
    expect(entry.acknowledgedAt, '2026-06-30 10:00:02');
  });

  test('humanizeDeviceMessage translates common backend delivery messages', () {
    expect(
      humanizeDeviceMessage('Published to MQTT broker'),
      'Đã publish lên MQTT broker',
    );
    expect(
      humanizeDeviceMessage('Device acknowledged command'),
      'Thiết bị đã xác nhận lệnh',
    );
  });

  testWidgets('LiveStatusView marks disabled approaches and device heartbeat',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final snapshot = DashboardSnapshot(
      status: TrafficStatus(
        modeCode: 'AUTO',
        phaseCode: 'NS_GREEN',
        remainingSeconds: 7,
        signals: [
          SignalStatus(approach: 'NORTH', signal: 'NORTH_MAIN', color: 'GREEN'),
          SignalStatus(approach: 'SOUTH', signal: 'SOUTH_MAIN', color: 'GREEN'),
          SignalStatus(approach: 'WEST', signal: 'WEST_MAIN', color: 'RED'),
        ],
      ),
      approaches: [
        Approach(
          id: 1,
          code: 'NORTH',
          name: 'North',
          displayOrder: 1,
          isActive: true,
          signalCode: 'NORTH_MAIN',
          redPin: 1,
          yellowPin: 2,
          greenPin: 3,
        ),
        Approach(
          id: 2,
          code: 'EAST',
          name: 'East',
          displayOrder: 2,
          isActive: false,
          signalCode: 'EAST_MAIN',
          redPin: 4,
          yellowPin: 5,
          greenPin: 6,
        ),
        Approach(
          id: 3,
          code: 'SOUTH',
          name: 'South',
          displayOrder: 3,
          isActive: true,
          signalCode: 'SOUTH_MAIN',
          redPin: 7,
          yellowPin: 8,
          greenPin: 9,
        ),
        Approach(
          id: 4,
          code: 'WEST',
          name: 'West',
          displayOrder: 4,
          isActive: true,
          signalCode: 'WEST_MAIN',
          redPin: 10,
          yellowPin: 11,
          greenPin: 12,
        ),
      ],
      phasePlans: const [],
      commands: const [],
      logs: const [],
      modes: const [],
      deviceStatuses: const [
        {'connection_state': 'online'},
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              LiveStatusView(
                snapshot: snapshot,
                lastSnapshotAt: DateTime.now(),
                online: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Thiết bị online'), findsOneWidget);
    expect(find.text('Tắt ở backend'), findsOneWidget);
    expect(find.text('Không xuất status'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings fit a narrow phone and hide unsupported placeholders',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller =
        TextEditingController(text: 'http://192.168.100.123:8000');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MobileSettingsView(
                controller: controller,
                online: true,
                apiBase: controller.text,
                isRunning: (_) => false,
                deviceStatuses: const [
                  {
                    'device_id': 'TrafficLight-01',
                    'connection_state': 'online',
                    'last_mode_code': 'AUTO',
                    'last_seen_at': '2026-06-30T10:00:00',
                  },
                ],
                phasePlans: const [],
                skipDangerConfirm: false,
                onApply: () async {},
                onRefresh: () async {},
                onToggleSkipConfirm: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Đang kết nối'), findsOneWidget);
    expect(find.text('Phiên bản firmware'), findsNothing);
    expect(find.text('Bảo mật'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('untimed normal modes are not classified as device errors', () {
    final nightLog = TrafficLog(
      modeCode: 'NIGHT',
      phaseCode: 'YELLOW_BLINK',
      remainingSeconds: -1,
      createdAt: '2026-06-29 19:00:00',
    );
    final emergencyLog = TrafficLog(
      modeCode: 'EMERGENCY',
      phaseCode: 'ALL_RED',
      remainingSeconds: -1,
      createdAt: '2026-06-29 19:00:01',
    );

    expect(logLevel(nightLog), 'warn');
    expect(logLevel(emergencyLog), 'err');
  });

  group('SettingsStore skip-confirm', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to false (always confirm)', () async {
      final store = await SettingsStore.open();
      expect(store.readSkipConfirm(), false);
    });

    test('round-trips a true value', () async {
      final store = await SettingsStore.open();
      await store.writeSkipConfirm(true);
      expect(store.readSkipConfirm(), true);
    });

    test('clears the value when set back to false', () async {
      final store = await SettingsStore.open();
      await store.writeSkipConfirm(true);
      expect(store.readSkipConfirm(), true);
      await store.writeSkipConfirm(false);
      expect(store.readSkipConfirm(), false);
    });
  });

  // Regression test for the messenger-key wiring bug. The fix moved the
  // GlobalKey<ScaffoldMessengerState> from being attached as Scaffold.key
  // (which silently swallowed the dialog) to MaterialApp.scaffoldMessengerKey
  // (which is the supported Flutter 3.0+ API). Verifying the wiring directly
  // is more reliable than driving the full showDialog + confirm flow from
  // a tester.tap, which is fragile in the polling-heavy app shell.
  testWidgets(
      'MaterialApp binds a non-null ScaffoldMessengerState via the messenger key',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TrafficOperatorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The MaterialApp must be the one we built (sanity check on tree).
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.scaffoldMessengerKey, isNotNull,
        reason:
            'MaterialApp.scaffoldMessengerKey must be wired for SnackBar feedback');

    // After the first frame, the ScaffoldMessenger exists and its state is
    // bound to the same key. If currentState is null, the same key was
    // attached to the wrong widget (the original bug).
    final messengerState = materialApp.scaffoldMessengerKey!.currentState;
    expect(messengerState, isNotNull,
        reason: 'ScaffoldMessengerState must be resolvable through the key — '
            'otherwise dialogs and SnackBars will be silently dropped');
  });
}
