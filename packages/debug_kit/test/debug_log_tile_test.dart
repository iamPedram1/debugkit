import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/ui/widgets/debug_log_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows and copies the full log message', (tester) async {
    const longMessage =
        '[CanonicalDiff] client.canonicalStrokeJson={"strokes":[{"artboardId":"art_123","id":"stroke_456","layerId":"layer_789","points":[{"x":1,"y":2},{"x":3,"y":4},{"x":5,"y":6}]}]}';
    String? copiedText;

    final binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          copiedText = (methodCall.arguments as Map?)?['text'] as String?;
        }
        return null;
      },
    );

    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final entry = DebugLogEntry(
      id: 1,
      level: DebugLogLevel.info,
      source: DebugLogSource.app,
      message: longMessage,
      timestamp: DateTime(2026, 6, 23, 12, 34, 56),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DebugLogTile(entry: entry),
        ),
      ),
    );

    expect(find.text(longMessage), findsOneWidget);

    await tester.longPress(find.byType(DebugLogTile));
    await tester.pump();

    expect(copiedText, longMessage);
  });
}
