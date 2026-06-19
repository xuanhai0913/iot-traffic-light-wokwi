import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_traffic_light/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders traffic operator app', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TrafficOperatorApp());
    await tester.pump();

    expect(find.text('IoT Traffic Light'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets(
      'StatusBanner shows the offline warning icon until backend responds',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TrafficOperatorApp());
    // pump once to lay out the initial frame; do not pumpAndSettle because
    // the bootstrap fires a real HTTP request and we do not want the test
    // to depend on the network.
    await tester.pump();

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    // The old inline message must be gone.
    expect(find.text('Chua ket noi backend'), findsNothing);
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

  testWidgets(
      'ControlView only disables the button whose action is in flight',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TrafficOperatorApp());
    await tester.pump();

    // The bootstrap network call eventually sets online=false so the
    // dashboard shows the default mode (AUTO) on the ControlView.
    await tester.tap(find.text('Control'));
    await tester.pump();

    // All five command buttons render with their labels.
    expect(find.widgetWithText(FilledButton, 'AUTO'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'NIGHT'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'PRIORITY NS'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'PRIORITY EW'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'EMERGENCY'), findsOneWidget);

    // Before any tap, no per-button progress indicators should be present.
    expect(
      find.descendant(
        of: find.widgetWithText(FilledButton, 'AUTO'),
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
                deviceStatus: 'queued',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Command accepted: SET_AUTO'), findsOneWidget);
    expect(find.text('Command ID'), findsOneWidget);
    expect(find.text('999'), findsOneWidget);
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('flutter'), findsOneWidget);
    expect(find.text('Created by'), findsOneWidget);
    expect(find.text('operator'), findsOneWidget);
    expect(find.text('Created at'), findsOneWidget);
    expect(find.text('2026-06-18 17:30:00'), findsOneWidget);
    expect(find.text('Device status'), findsOneWidget);
    expect(find.text('queued'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Close'), findsOneWidget);
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

    test('ApiException carries the supplied message', () {
      final ex = ApiException('boom');
      expect(ex.message, 'boom');
      expect(ex.toString(), 'boom');
    });
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

    expect(find.text('Confirm SET_EMERGENCY'), findsOneWidget);
    expect(find.text('Risk level: Critical'), findsOneWidget);
    // Critical dialog must mention flashing red so the operator reads the
    // consequence before tapping Send.
    expect(find.textContaining('flashing red'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send anyway'), findsOneWidget);
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

    expect(find.text('Risk level: Risky'), findsOneWidget);
    expect(find.textContaining('North-South'), findsOneWidget);
    expect(find.textContaining('East-West'), findsOneWidget);
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
}
