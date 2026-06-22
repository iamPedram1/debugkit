import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/ui/screens/debug_network_inspector_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DebugLogEntry _networkEntry({
  required int id,
  required String method,
  required String path,
  required String phase,
  int? status,
  int? durationMs,
  String? requestId,
  DateTime? timestamp,
}) {
  return DebugLogEntry(
    id: id,
    level: DebugLogLevel.info,
    source: DebugLogSource.dio,
    message: '$method $path',
    timestamp: timestamp ?? DateTime(2026, 1, 1, 12, 0, id),
    requestId: requestId,
    metadata: {
      'kind': 'networkTransaction',
      'method': method,
      'path': path,
      'phase': phase,
      if (status != null) 'status': '$status',
      if (durationMs != null) 'duration_ms': '$durationMs',
      if (durationMs != null) 'durationMs': '$durationMs',
    },
  );
}

void _seedNetworkRequests(DebugKitController controller) {
  controller.init(enabled: true);
  controller.store.clear();

  final entries = <DebugLogEntry>[
    for (var i = 1; i <= 20; i++)
      _networkEntry(
        id: i,
        method: i.isEven ? 'GET' : 'POST',
        path: '/network/$i',
        phase: i % 5 == 0
            ? 'failed'
            : i % 4 == 0
                ? 'pending'
                : 'completed',
        status: i % 5 == 0
            ? 500
            : i % 4 == 0
                ? null
                : 200,
        durationMs: 80 + i * 25,
        requestId: 'dio_$i',
        timestamp: DateTime(2026, 1, 1, 12, 0, 0).add(Duration(seconds: i)),
      ),
  ];

  controller.store.addLogs(entries);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _seedNetworkRequests(DebugKitController());
  });

  tearDown(() {
    DebugKitController().store.clear();
  });

  Widget wrapApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('scrolling down collapses controls and scrolling up reveals them',
      (tester) async {
    await tester.pumpWidget(wrapApp(const DebugNetworkSummaryScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('PATCH'), findsOneWidget);

    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);

    await tester.drag(listFinder, const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('PATCH'), findsNothing);

    await tester.drag(listFinder, const Offset(0, 350));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('PATCH'), findsOneWidget);
  });

  testWidgets('focused search stays visible while scrolling', (tester) async {
    await tester.pumpWidget(wrapApp(const DebugNetworkSummaryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'network');
    await tester.pump();

    final listFinder = find.byType(ListView);
    await tester.drag(listFinder, const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('PATCH'), findsOneWidget);
  });

  testWidgets('timeline toggle hides and restores the overview state',
      (tester) async {
    await tester.pumpWidget(wrapApp(const DebugNetworkSummaryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Timeline'), findsOneWidget);

    await tester.tap(find.text('/network/20'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Selected: GET /network/20'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide timeline'));
    await tester.pumpAndSettle();

    expect(find.text('Hide'), findsNothing);
    expect(find.textContaining('Selected: GET /network/20'), findsNothing);

    await tester.tap(find.byTooltip('Show timeline'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Selected: GET /network/20'), findsOneWidget);
  });
}
