import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ordermate/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OrderMate Smoke Test: Login & Navigation',
      (WidgetTester tester) async {
    // 1. Start App
    app.main();
    await tester.pumpAndSettle();

    // 2. Verify Login Screen
    expect(find.text('Login'), findsOneWidget);

    // *Note: Without specific credentials or valid Key ID, full automation is tricky blindly.
    // This test confirms the app launches and reaches Login screen on Web/Windows without crashing.*

    // Future expansion:
    // await tester.enterText(find.byType(TextFormField).at(0), 'USAMA');
    // await tester.enterText(find.byType(TextFormField).at(1), '70001');
    // await tester.tap(find.text('Login'));
    // await tester.pumpAndSettle();
    // expect(find.text('Dashboard'), findsOneWidget);
  });
}
