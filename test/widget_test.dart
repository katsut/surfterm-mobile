import 'package:flutter_test/flutter_test.dart';

import 'package:surfterm_mobile/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SurftermApp());

    // Verify that the scan screen is shown.
    expect(find.text('Surfterm'), findsOneWidget);
  });
}
