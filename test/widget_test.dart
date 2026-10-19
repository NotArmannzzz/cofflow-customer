import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_customer_cofflow/main.dart';

void main() {
  testWidgets('Shows splash branding when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(const KoncoSpaceApp(loggedIn: false));
    await tester.pump();

    expect(find.text('Konco Space'), findsOneWidget);

    // Drain the splash → login navigation timer so no timers stay pending.
    await tester.pump(const Duration(seconds: 3));
  });
}
