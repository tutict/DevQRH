import 'package:devqrh_mobile/app/devqrh_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders DevQRH home shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DevQrhApp());
    await tester.pumpAndSettle();

    expect(find.text('DevQRH'), findsOneWidget);
    expect(find.text('症状检索'), findsOneWidget);
  });
}
