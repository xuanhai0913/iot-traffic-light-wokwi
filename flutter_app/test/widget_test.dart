import 'package:flutter_test/flutter_test.dart';
import 'package:iot_traffic_light/main.dart';

void main() {
  testWidgets('renders traffic operator app', (WidgetTester tester) async {
    await tester.pumpWidget(const TrafficOperatorApp());

    expect(find.text('IoT Traffic Light'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
