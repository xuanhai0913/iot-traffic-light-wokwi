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
