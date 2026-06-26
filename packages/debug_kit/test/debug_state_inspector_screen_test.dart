import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/ui/screens/debug_state_inspector_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DebugKit.init(enabled: true, printToConsole: false);
    DebugKit.clearStateEvents();
  });

  tearDown(() {
    DebugKit.clearStateEvents();
  });

  testWidgets('State toolbar search field expands in wide layout', (
    tester,
  ) async {
    await _pumpScreen(tester, const Size(1280, 900));

    final searchWidth = tester.getSize(find.byType(TextField).first).width;

    expect(searchWidth, greaterThan(450));
    expect(find.text('Source'), findsNothing);
  });

  testWidgets('State toolbar does not overflow in narrow layout', (
    tester,
  ) async {
    await _pumpScreen(tester, const Size(420, 900));

    expect(tester.takeException(), isNull);

    final searchWidth = tester.getSize(find.byType(TextField).first).width;

    expect(searchWidth, greaterThan(300));
  });

  testWidgets('State event rows render inline diff previews', (tester) async {
    _recordNestedStateEvent(
      id: 'state_1',
      changes: const [
        DebugStateDiffEntry(
          path: 'profile.metadata.status',
          type: DebugStateDiffType.changed,
          previousValuePreview: 'idle',
          nextValuePreview: 'active',
        ),
        DebugStateDiffEntry(
          path: 'profile.metadata.theme',
          type: DebugStateDiffType.changed,
          previousValuePreview: 'dark',
          nextValuePreview: 'light',
        ),
      ],
    );

    await _pumpScreen(tester, const Size(520, 900));

    expect(find.text('nestedProfileProvider'), findsOneWidget);
    expect(find.text('profile.metadata.status'), findsOneWidget);
    expect(find.text('- idle'), findsOneWidget);
    expect(find.text('+ active'), findsOneWidget);
    expect(find.text('profile.metadata.theme'), findsOneWidget);
    expect(find.text('- dark'), findsOneWidget);
    expect(find.text('+ light'), findsOneWidget);
  });

  testWidgets('State event rows show remaining change count', (tester) async {
    _recordNestedStateEvent(
      id: 'state_2',
      changes: const [
        DebugStateDiffEntry(
          path: 'profile.metadata.status',
          type: DebugStateDiffType.changed,
          previousValuePreview: 'idle',
          nextValuePreview: 'active',
        ),
        DebugStateDiffEntry(
          path: 'profile.metadata.theme',
          type: DebugStateDiffType.changed,
          previousValuePreview: 'dark',
          nextValuePreview: 'light',
        ),
        DebugStateDiffEntry(
          path: 'profile.metadata.language',
          type: DebugStateDiffType.changed,
          previousValuePreview: 'en',
          nextValuePreview: 'fa',
        ),
      ],
    );

    await _pumpScreen(tester, const Size(520, 900));

    expect(find.text('+ 1 more change'), findsOneWidget);
  });

  testWidgets('Search matches changed paths and diff values', (tester) async {
    _recordNestedStateEvent(
      id: 'state_3',
      changes: const [
        DebugStateDiffEntry(
          path: 'profile.metadata.status',
          type: DebugStateDiffType.changed,
          previousValuePreview: 'idle',
          nextValuePreview: 'active',
        ),
      ],
    );

    await _pumpScreen(tester, const Size(520, 900));

    final search = find.byType(TextField).first;

    await tester.enterText(search, 'status');
    await tester.pumpAndSettle();
    expect(find.text('nestedProfileProvider'), findsOneWidget);

    await tester.enterText(search, 'idle');
    await tester.pumpAndSettle();
    expect(find.text('nestedProfileProvider'), findsOneWidget);

    await tester.enterText(search, 'active');
    await tester.pumpAndSettle();
    expect(find.text('nestedProfileProvider'), findsOneWidget);
  });

  testWidgets('Event type filtering still works and source filter is absent', (
    tester,
  ) async {
    _recordNestedStateEvent(
      id: 'state_4',
      eventType: DebugStateEventType.updated,
      changes: const [
        DebugStateDiffEntry(
          path: 'profile.metadata.status',
          type: DebugStateDiffType.changed,
          previousValuePreview: 'idle',
          nextValuePreview: 'active',
        ),
      ],
    );
    _recordNestedStateEvent(
      id: 'state_5',
      eventType: DebugStateEventType.disposed,
      changes: const [],
    );

    await _pumpScreen(tester, const Size(520, 900));

    expect(find.text('Source'), findsNothing);
    expect(find.byType(FilterChip),
        findsNWidgets(DebugStateEventType.values.length));

    await tester.tap(
      find.widgetWithText(FilterChip, DebugStateEventType.disposed.label),
    );
    await tester.pumpAndSettle();

    expect(find.text('nestedProfileProvider'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    const MaterialApp(
      home: DebugStateInspectorScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void _recordNestedStateEvent({
  required String id,
  DebugStateEventType eventType = DebugStateEventType.updated,
  required List<DebugStateDiffEntry> changes,
  String? diffPreview,
}) {
  DebugKit.state.record(
    DebugStateEvent(
      id: id,
      timestamp: DateTime.now(),
      source: 'riverpod',
      name: 'nestedProfileProvider',
      type: 'NotifierProvider',
      eventType: eventType,
      diffPreview: diffPreview,
      changes: changes,
    ),
  );
}
