import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/app.dart';

void main() {
  testWidgets('RequestManagerApp initialization smoke test',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RequestManagerApp());

    // Verify that the title of the app bar is present in the home/preview page.
    expect(find.text('Request Manager App'), findsOneWidget);
  });
}
