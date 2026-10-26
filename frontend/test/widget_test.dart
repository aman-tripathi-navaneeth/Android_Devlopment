import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_app/main.dart';
import 'package:pharmacy_app/features/shell/screens/main_shell_screen.dart';
import 'package:pharmacy_app/features/dashboard/screens/dashboard_screen.dart';

void main() {
  testWidgets('Pharmacy app launches and renders shell and dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const PharmacyApp());
    await tester.pumpAndSettle();

    // Verify MainShellScreen is mounted
    expect(find.byType(MainShellScreen), findsOneWidget);

    // Verify DashboardScreen is active
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Verify store subtitle is displayed
    expect(find.text('Sri Balaji Medical Store'), findsAtLeastNWidgets(1));
  });
}
