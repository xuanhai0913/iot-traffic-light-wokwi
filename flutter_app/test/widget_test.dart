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
}
