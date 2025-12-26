import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const TithiApp());

    // Verify the app title is present
    expect(find.text('Tithi'), findsOneWidget);
  });
}
