import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/ui/screens/debug_kit_console_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildApp({
  required GlobalKey<NavigatorState> navigatorKey,
  required Widget child,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    home: DebugKitOverlay(child: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DebugKitOverlay', () {
    testWidgets('shows the floating button by default', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      DebugKit.init(enabled: true, navigatorKey: navigatorKey);

      await tester.pumpWidget(
        _buildApp(
          navigatorKey: navigatorKey,
          child: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bug_report_rounded), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('hides the floating button when disabled explicitly',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      DebugKit.init(
        enabled: true,
        navigatorKey: navigatorKey,
        disableDefaultOverlayButton: true,
      );

      await tester.pumpWidget(
        _buildApp(
          navigatorKey: navigatorKey,
          child: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bug_report_rounded), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('opens and closes the console from the public API',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      DebugKit.init(
        enabled: true,
        navigatorKey: navigatorKey,
        disableDefaultOverlayButton: true,
      );

      await tester.pumpWidget(
        _buildApp(
          navigatorKey: navigatorKey,
          child: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpAndSettle();

      DebugKit.open();
      await tester.pumpAndSettle();
      expect(find.byType(DebugKitConsoleScreen), findsOneWidget);

      DebugKit.close();
      await tester.pumpAndSettle();
      expect(find.byType(DebugKitConsoleScreen), findsNothing);
    });
  });
}
