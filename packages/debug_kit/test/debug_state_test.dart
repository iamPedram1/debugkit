import 'package:debug_kit/debug_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DebugKit.init(
      enabled: true,
      printToConsole: false,
      maxStateEvents: 2,
    );
    DebugKit.clearStateEvents();
  });

  tearDown(() {
    DebugKit.clearStateEvents();
  });

  test('DebugStateEvent serializes and deserializes', () {
    final event = DebugStateEvent(
      id: 'state_1',
      timestamp: DateTime.parse('2026-06-26T12:00:00.000Z'),
      source: 'riverpod',
      name: 'authProvider',
      type: 'NotifierProvider',
      eventType: DebugStateEventType.updated,
      previousValuePreview: 'guest',
      nextValuePreview: 'signed-in',
      diffPreview: 'guest -> signed-in',
      changes: const [
        DebugStateDiffEntry(
          path: 'auth.status',
          type: DebugStateDiffType.changed,
          previousValuePreview: 'guest',
          nextValuePreview: 'signed-in',
        ),
      ],
      error: 'none',
      stackTrace: '#0 main',
      metadata: const {'provider_name': 'authProvider'},
    );

    final json = event.toJson();
    final roundTrip = DebugStateEvent.fromJson(json);

    expect(roundTrip.id, event.id);
    expect(roundTrip.timestamp, event.timestamp);
    expect(roundTrip.source, event.source);
    expect(roundTrip.name, event.name);
    expect(roundTrip.type, event.type);
    expect(roundTrip.eventType, event.eventType);
    expect(roundTrip.previousValuePreview, event.previousValuePreview);
    expect(roundTrip.nextValuePreview, event.nextValuePreview);
    expect(roundTrip.diffPreview, event.diffPreview);
    expect(roundTrip.changes.length, 1);
    expect(roundTrip.changes.first.path, 'auth.status');
    expect(roundTrip.changes.first.type, DebugStateDiffType.changed);
    expect(roundTrip.error, event.error);
    expect(roundTrip.stackTrace, event.stackTrace);
    expect(roundTrip.metadata, event.metadata);
  });

  test('records state events when enabled', () {
    DebugKit.state.record(
      DebugStateEvent(
        id: 'state_1',
        timestamp: DateTime.now(),
        source: 'app',
        name: 'counter',
        eventType: DebugStateEventType.added,
      ),
    );

    expect(DebugKit.controller.stateStore.events.length, 1);
    expect(DebugKit.controller.stateStore.events.first.name, 'counter');
  });

  test('state recording is bounded', () {
    for (var i = 0; i < 3; i++) {
      DebugKit.state.record(
        DebugStateEvent(
          id: 'state_$i',
          timestamp: DateTime.now(),
          source: 'app',
          name: 'event_$i',
          eventType: DebugStateEventType.updated,
        ),
      );
    }

    expect(DebugKit.controller.stateStore.events.length, 2);
    expect(DebugKit.controller.stateStore.events.first.name, 'event_1');
    expect(DebugKit.controller.stateStore.events.last.name, 'event_2');
  });

  test('clear removes all state events', () {
    DebugKit.state.record(
      DebugStateEvent(
        id: 'state_1',
        timestamp: DateTime.now(),
        source: 'app',
        name: 'counter',
        eventType: DebugStateEventType.updated,
      ),
    );
    DebugKit.state.clear();

    expect(DebugKit.controller.stateStore.events, isEmpty);
  });

  test('state recording is a no-op when disabled', () {
    DebugKit.init(enabled: false);
    DebugKit.state.record(
      DebugStateEvent(
        id: 'state_1',
        timestamp: DateTime.now(),
        source: 'app',
        name: 'counter',
        eventType: DebugStateEventType.updated,
      ),
    );

    expect(DebugKit.controller.stateStore.events, isEmpty);
  });

  test('paused state recording is a no-op until resumed', () {
    DebugKit.state.pause();
    DebugKit.state.record(
      DebugStateEvent(
        id: 'state_1',
        timestamp: DateTime.now(),
        source: 'app',
        name: 'paused',
        eventType: DebugStateEventType.updated,
      ),
    );

    expect(DebugKit.controller.stateStore.events, isEmpty);

    DebugKit.state.resume();
    DebugKit.state.record(
      DebugStateEvent(
        id: 'state_2',
        timestamp: DateTime.now(),
        source: 'app',
        name: 'resumed',
        eventType: DebugStateEventType.updated,
      ),
    );

    expect(DebugKit.controller.stateStore.events.length, 1);
    expect(DebugKit.controller.stateStore.events.first.name, 'resumed');
  });

  test('state previews are sanitized and truncated', () {
    const privateKey =
        '0x1234567890123456789012345678901234567890123456789012345678901234';
    DebugKit.state.record(
      DebugStateEvent(
        id: 'state_1',
        timestamp: DateTime.now(),
        source: 'app',
        name: 'secretState',
        eventType: DebugStateEventType.updated,
        nextValuePreview: '$privateKey token=abc123secret ${'x' * 600}',
      ),
    );

    final event = DebugKit.controller.stateStore.events.first;
    expect(event.nextValuePreview, isNot(contains('abc123secret')));
    expect(event.nextValuePreview, contains('[REDACTED PRIVATE KEY]'));
    expect(event.nextValuePreview!.length, lessThanOrEqualTo(503));
  });

  test('state diff builder detects nested map changes', () {
    final diffs = DebugStateDiffBuilder.build(
      {
        'profile': {
          'metadata': {
            'status': 'idle',
            'theme': 'dark',
          },
        },
      },
      {
        'profile': {
          'metadata': {
            'status': 'active',
            'theme': 'dark',
          },
        },
      },
    );

    expect(diffs, hasLength(1));
    expect(diffs.single.path, 'profile.metadata.status');
    expect(diffs.single.type, DebugStateDiffType.changed);
    expect(diffs.single.previousValuePreview, 'idle');
    expect(diffs.single.nextValuePreview, 'active');
  });

  test('state diff builder detects added and removed keys', () {
    final added = DebugStateDiffBuilder.build(
      {
        'profile': {'name': 'Pedram'}
      },
      {
        'profile': {'name': 'Pedram', 'role': 'admin'},
      },
    );
    final removed = DebugStateDiffBuilder.build(
      {
        'profile': {'name': 'Pedram', 'role': 'admin'},
      },
      {
        'profile': {'name': 'Pedram'}
      },
    );

    expect(added.single.path, 'profile.role');
    expect(added.single.type, DebugStateDiffType.added);
    expect(removed.single.path, 'profile.role');
    expect(removed.single.type, DebugStateDiffType.removed);
  });

  test('state diff builder respects depth and entry limits', () {
    final diffs = DebugStateDiffBuilder.build(
      {
        'a': {
          'b': {
            'c': {
              'd': {
                'e': 'old',
              },
            },
          },
        },
      },
      {
        'a': {
          'b': {
            'c': {
              'd': {
                'e': 'new',
              },
            },
          },
        },
      },
      maxDepth: 2,
      maxEntries: 1,
    );

    expect(diffs, hasLength(1));
    expect(diffs.first.type, DebugStateDiffType.changed);
  });

  test('state diff builder redacts secrets in previews', () {
    const privateKey =
        '0x1234567890123456789012345678901234567890123456789012345678901234';
    const rotatedKey =
        '0x2234567890123456789012345678901234567890123456789012345678901234';
    final diffs = DebugStateDiffBuilder.build(
      {'key': privateKey},
      {'key': rotatedKey},
    );

    expect(
        diffs.single.previousValuePreview, contains('[REDACTED PRIVATE KEY]'));
    expect(diffs.single.nextValuePreview, contains('[REDACTED PRIVATE KEY]'));
  });
}
