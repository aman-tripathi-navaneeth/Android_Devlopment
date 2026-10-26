import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_app/main.dart';
import 'package:pharmacy_app/core/ui/app_top_bar.dart';
import 'package:pharmacy_app/core/ui/bottom_nav_bar.dart';
import 'package:pharmacy_app/features/shell/screens/main_shell_screen.dart';
import 'package:pharmacy_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:pharmacy_app/features/camera/screens/camera_capture_screen.dart';
import 'package:pharmacy_app/features/invoices/screens/invoice_scan_screen.dart';
import 'package:pharmacy_app/features/sales/screens/sales_report_scan_screen.dart';
import 'package:pharmacy_app/core/ui/scan_selection_sheet.dart';

void main() {
  testWidgets('Single global Camera entry point, scan selector, viewfinder and workflow navigation test', (WidgetTester tester) async {
    await tester.pumpWidget(const PharmacyApp());
    await tester.pumpAndSettle();

    // 1. Verify Shell and 5 Bottom Navigation destinations with Camera in center
    expect(find.byType(MainShellScreen), findsOneWidget);
    expect(find.byType(BottomNavBar), findsOneWidget);

    expect(find.widgetWithText(InkWell, 'Home'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Medicines'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Camera'), findsOneWidget); // EXACTLY ONE prominent Camera entry point!
    expect(find.widgetWithText(InkWell, 'Transactions'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'More'), findsOneWidget);

    // 2. Confirm NO scan action in the AppTopBar / header
    expect(
      find.descendant(of: find.byType(AppTopBar), matching: find.byIcon(Icons.camera_alt_outlined)),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(AppTopBar), matching: find.byIcon(Icons.document_scanner_rounded)),
      findsNothing,
    );

    // 3. Confirm Home dashboard has NO duplicate scan buttons/cards
    expect(
      find.descendant(of: find.byType(DashboardScreen), matching: find.text('Scan Document')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(DashboardScreen), matching: find.text('+ Scan Invoice')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(DashboardScreen), matching: find.text('+ Scan Report')),
      findsNothing,
    );

    // Home quick actions only contain + New PO and Add Medicine
    expect(find.text('New PO'), findsOneWidget);
    expect(find.text('Add Medicine'), findsOneWidget);

    // 4. Tap the single central Camera button
    final globalCameraButton = find.widgetWithText(InkWell, 'Camera');
    expect(globalCameraButton, findsOneWidget);
    await tester.tap(globalCameraButton);
    await tester.pumpAndSettle();

    // 5. Verify ScanSelectionSheet opens with required title, options and descriptions
    expect(find.byType(ScanSelectionSheet), findsOneWidget);
    expect(find.text('What would you like to scan?'), findsOneWidget);

    // Option A: Purchase Invoice (Stock In)
    expect(find.text('Purchase Invoice'), findsOneWidget);
    expect(find.text('Stock In'), findsOneWidget);
    expect(find.text('Scan a supplier invoice to add received stock.'), findsOneWidget);

    // Option B: Sales Report (Stock Out)
    expect(find.text('Sales Report'), findsOneWidget);
    expect(find.text('Stock Out'), findsOneWidget);
    expect(find.text('Scan a sales report to record sold medicines.'), findsOneWidget);

    // 6. Test Option A: Purchase Invoice workflow -> Camera Viewfinder
    await tester.tap(find.text('Purchase Invoice'));
    await tester.pumpAndSettle();

    // Verify CameraCaptureScreen is opened with live viewfinder
    expect(find.byType(CameraCaptureScreen), findsOneWidget);
    expect(find.text('Position the document within the frame'), findsOneWidget);
    expect(find.text('DOCUMENT'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);

    // Tap Upload / Shutter to proceed to 4-step Review workflow
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Verify InvoiceScanScreen is pushed with Step 1: Review Extracted Lines
    expect(find.byType(InvoiceScanScreen), findsOneWidget);
    expect(find.textContaining('INV-9032'), findsWidgets);
    expect(find.text('Continue to Matching ›'), findsOneWidget);

    // Return to main shell
    Navigator.of(tester.element(find.byType(InvoiceScanScreen))).pop();
    await tester.pumpAndSettle();

    // 7. Tap central Camera button again to test Option B
    await tester.tap(find.widgetWithText(InkWell, 'Camera'));
    await tester.pumpAndSettle();

    expect(find.byType(ScanSelectionSheet), findsOneWidget);

    // Test Option B: Sales Report workflow -> Camera Viewfinder
    await tester.tap(find.text('Sales Report'));
    await tester.pumpAndSettle();

    expect(find.byType(CameraCaptureScreen), findsOneWidget);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Verify SalesReportScanScreen is pushed
    expect(find.byType(SalesReportScanScreen), findsOneWidget);

    // Return to main shell
    Navigator.of(tester.element(find.byType(SalesReportScanScreen))).pop();
    await tester.pumpAndSettle();

    // 8. Confirm page state is preserved on Home screen
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('New PO'), findsOneWidget);
  });
}
