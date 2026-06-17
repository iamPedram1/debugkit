import 'package:flutter_test/flutter_test.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/core/store/debug_log_store.dart';
import 'package:debug_kit/src/utils/export/debug_log_export_formatter.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DebugLogEntry _entry({
  int id = 1,
  DebugLogLevel level = DebugLogLevel.info,
  DebugLogSource source = DebugLogSource.app,
  String message = 'Test log',
  String? error,
  String? stackTrace,
  Map<String, String>? metadata,
  String? requestId,
  String? traceId,
}) {
  return DebugLogEntry(
    id: id,
    level: level,
    source: source,
    message: message,
    timestamp: DateTime.now(),
    error: error,
    stackTrace: stackTrace,
    metadata: metadata,
    requestId: requestId,
    traceId: traceId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Fingerprint
  // ---------------------------------------------------------------------------
  group('DebugLogEntry.fingerprint', () {
    test('two identical entries have the same fingerprint', () {
      final a = _entry(id: 1, message: 'hello');
      final b = _entry(id: 2, message: 'hello');
      expect(a.fingerprint, b.fingerprint);
    });

    test('different messages produce different fingerprints', () {
      final a = _entry(message: 'foo');
      final b = _entry(message: 'bar');
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('different levels produce different fingerprints', () {
      final a = _entry(level: DebugLogLevel.info);
      final b = _entry(level: DebugLogLevel.error);
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('different sources produce different fingerprints', () {
      final a = _entry(source: DebugLogSource.app);
      final b = _entry(source: DebugLogSource.dio);
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('different errors produce different fingerprints', () {
      final a = _entry(error: 'Timeout');
      final b = _entry(error: 'Auth failed');
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('fingerprint ignores id', () {
      final a = _entry(id: 1);
      final b = _entry(id: 99);
      expect(a.fingerprint, b.fingerprint);
    });

    test('fingerprint ignores requestId', () {
      final a = _entry(requestId: 'dio_1');
      final b = _entry(requestId: 'dio_2');
      expect(a.fingerprint, b.fingerprint);
    });

    test('fingerprint ignores volatile metadata keys', () {
      final a = _entry(metadata: {'duration_ms': '100', 'status': '200'});
      final b = _entry(metadata: {'duration_ms': '999', 'status': '200'});
      expect(a.fingerprint, b.fingerprint);
    });

    test('fingerprint ignores response_headers metadata key', () {
      final a = _entry(metadata: {'response_headers': 'old'});
      final b = _entry(metadata: {'response_headers': 'new'});
      expect(a.fingerprint, b.fingerprint);
    });

    test('fingerprint includes stable metadata keys', () {
      final a = _entry(metadata: {'provider_name': 'authProvider'});
      final b = _entry(metadata: {'provider_name': 'cartProvider'});
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('fingerprint is stable regardless of metadata insertion order', () {
      final a = _entry(metadata: {'key_a': 'val_a', 'key_b': 'val_b'});
      final b = _entry(metadata: {'key_b': 'val_b', 'key_a': 'val_a'});
      expect(a.fingerprint, b.fingerprint);
    });

    test('different traceIds produce different fingerprints', () {
      final a = _entry(traceId: 'trace_1');
      final b = _entry(traceId: 'trace_2');
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('null traceId and non-null traceId differ', () {
      final a = _entry(traceId: null);
      final b = _entry(traceId: 'trace_1');
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('fingerprint includes first stack trace line only', () {
      const stack = '#0 foo (foo.dart:10)\n#1 bar (bar.dart:20)';
      final a = _entry(stackTrace: stack);
      final b =
          _entry(stackTrace: '#0 foo (foo.dart:10)\n#1 baz (baz.dart:99)');
      // First lines are identical — fingerprints should match
      expect(a.fingerprint, b.fingerprint);
    });

    test('different first stack lines differ', () {
      final a = _entry(stackTrace: '#0 foo (foo.dart:10)');
      final b = _entry(stackTrace: '#0 bar (bar.dart:20)');
      expect(a.fingerprint, isNot(b.fingerprint));
    });
  });

  // ---------------------------------------------------------------------------
  // copyWithRepeatIncrement
  // ---------------------------------------------------------------------------
  group('DebugLogEntry.copyWithRepeatIncrement', () {
    test('increments repeatCount by 1', () {
      final entry = _entry();
      expect(entry.repeatCount, 1);
      final incremented = entry.copyWithRepeatIncrement(DateTime.now());
      expect(incremented.repeatCount, 2);
    });

    test('updates lastSeenAt', () {
      final entry = _entry();
      expect(entry.lastSeenAt, isNull);
      final now = DateTime.now();
      final incremented = entry.copyWithRepeatIncrement(now);
      expect(incremented.lastSeenAt, now);
    });

    test('preserves original timestamp', () {
      final entry = _entry();
      final original = entry.timestamp;
      final incremented = entry.copyWithRepeatIncrement(DateTime.now());
      expect(incremented.timestamp, original);
    });

    test('increments multiple times correctly', () {
      var entry = _entry();
      for (var i = 0; i < 9; i++) {
        entry = entry.copyWithRepeatIncrement(DateTime.now());
      }
      expect(entry.repeatCount, 10);
    });
  });

  // ---------------------------------------------------------------------------
  // DebugLogStore — grouping enabled (default)
  // ---------------------------------------------------------------------------
  group('DebugLogStore grouping enabled', () {
    late DebugLogStore store;

    setUp(() {
      store = DebugLogStore(maxLogs: 10, groupRepeated: true);
    });

    test('consecutive identical logs are grouped into one entry', () {
      store.addLog(_entry(id: 1, message: 'Retrying'));
      store.addLog(_entry(id: 2, message: 'Retrying'));
      store.addLog(_entry(id: 3, message: 'Retrying'));

      expect(store.logs.length, 1);
      expect(store.logs.first.repeatCount, 3);
      expect(store.logs.first.message, 'Retrying');
    });

    test('repeatCount increments on each duplicate', () {
      store.addLog(_entry(id: 1));
      store.addLog(_entry(id: 2));
      store.addLog(_entry(id: 3));
      store.addLog(_entry(id: 4));

      expect(store.logs.first.repeatCount, 4);
    });

    test('lastSeenAt is updated on each repeat', () {
      store.addLog(_entry(id: 1));
      expect(store.logs.first.lastSeenAt, isNull);

      store.addLog(_entry(id: 2));
      expect(store.logs.first.lastSeenAt, isNotNull);

      final before = store.logs.first.lastSeenAt!;
      store.addLog(_entry(id: 3));
      expect(
        store.logs.first.lastSeenAt!.isAfter(before) ||
            store.logs.first.lastSeenAt == before,
        isTrue,
      );
    });

    test('non-consecutive duplicates are NOT globally merged', () {
      store.addLog(_entry(id: 1, message: 'A'));
      store.addLog(_entry(id: 2, message: 'B'));
      store.addLog(_entry(id: 3, message: 'A'));

      // A × B × A = 3 separate rows
      expect(store.logs.length, 3);
      expect(store.logs[0].message, 'A');
      expect(store.logs[0].repeatCount, 1);
      expect(store.logs[1].message, 'B');
      expect(store.logs[2].message, 'A');
      expect(store.logs[2].repeatCount, 1);
    });

    test('different levels are not grouped', () {
      store.addLog(_entry(level: DebugLogLevel.info));
      store.addLog(_entry(level: DebugLogLevel.error));

      expect(store.logs.length, 2);
    });

    test('different sources are not grouped', () {
      store.addLog(_entry(source: DebugLogSource.app));
      store.addLog(_entry(source: DebugLogSource.dio));

      expect(store.logs.length, 2);
    });

    test('different errors prevent grouping', () {
      store.addLog(_entry(error: 'Timeout'));
      store.addLog(_entry(error: 'Auth failed'));

      expect(store.logs.length, 2);
    });

    test('different stable metadata prevents grouping', () {
      store.addLog(_entry(metadata: {'provider_name': 'authProvider'}));
      store.addLog(_entry(metadata: {'provider_name': 'cartProvider'}));

      expect(store.logs.length, 2);
    });

    test('entries with a requestId are never grouped regardless of message',
        () {
      // Entries with requestId are individually addressable by the Dio adapter.
      // Grouping them would break updateLogByRequestId.
      store.addLog(_entry(
          message: 'GET /profile failed',
          requestId: 'dio_1',
          metadata: {'request_id': 'dio_1', 'error_type': 'timeout'}));
      store.addLog(_entry(
          message: 'GET /profile failed',
          requestId: 'dio_2',
          metadata: {'request_id': 'dio_2', 'error_type': 'timeout'}));

      // Must be 2 separate entries — never merged
      expect(store.logs.length, 2);
      expect(store.logs[0].requestId, 'dio_1');
      expect(store.logs[1].requestId, 'dio_2');
      expect(store.logs[0].repeatCount, 1);
      expect(store.logs[1].repeatCount, 1);
    });

    test('grouped entry does not evict old logs unnecessarily', () {
      // Fill store with distinct entries
      for (var i = 0; i < 5; i++) {
        store.addLog(_entry(id: i, message: 'Entry $i'));
      }
      expect(store.logs.length, 5);

      // Repeat the last entry — should NOT evict
      store.addLog(_entry(id: 99, message: 'Entry 4'));
      expect(store.logs.length, 5);
      expect(store.logs.last.repeatCount, 2);
    });

    test('maxLogs counts grouped entries, not raw emissions', () {
      final smallStore = DebugLogStore(maxLogs: 3, groupRepeated: true);

      // 3 distinct messages fill the store
      smallStore.addLog(_entry(id: 1, message: 'A'));
      smallStore.addLog(_entry(id: 2, message: 'B'));
      smallStore.addLog(_entry(id: 3, message: 'C'));
      expect(smallStore.logs.length, 3);

      // Repeating 'C' should NOT evict — it groups into the tail
      smallStore.addLog(_entry(id: 4, message: 'C'));
      expect(smallStore.logs.length, 3);
      expect(smallStore.logs.last.repeatCount, 2);

      // A new distinct entry evicts the oldest
      smallStore.addLog(_entry(id: 5, message: 'D'));
      expect(smallStore.logs.length, 3);
      expect(smallStore.logs.first.message, 'B');
    });

    test('clear works after grouped entries', () {
      store.addLog(_entry(id: 1));
      store.addLog(_entry(id: 2));
      store.addLog(_entry(id: 3));
      expect(store.logs.first.repeatCount, 3);

      store.clear();
      expect(store.logs.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // DebugLogStore — grouping disabled
  // ---------------------------------------------------------------------------
  group('DebugLogStore grouping disabled', () {
    late DebugLogStore store;

    setUp(() {
      store = DebugLogStore(maxLogs: 10, groupRepeated: false);
    });

    test('consecutive identical logs are stored as separate entries', () {
      store.addLog(_entry(id: 1, message: 'Retrying'));
      store.addLog(_entry(id: 2, message: 'Retrying'));
      store.addLog(_entry(id: 3, message: 'Retrying'));

      expect(store.logs.length, 3);
      for (final entry in store.logs) {
        expect(entry.repeatCount, 1);
      }
    });

    test('evicts oldest when full', () {
      final smallStore = DebugLogStore(maxLogs: 3, groupRepeated: false);
      for (var i = 1; i <= 5; i++) {
        smallStore.addLog(_entry(id: i, message: 'Log $i'));
      }
      expect(smallStore.logs.length, 3);
      expect(smallStore.logs.first.message, 'Log 3');
      expect(smallStore.logs.last.message, 'Log 5');
    });
  });

  // ---------------------------------------------------------------------------
  // DebugKitController — groupRepeatedLogs config wiring
  // ---------------------------------------------------------------------------
  group('DebugKitController groupRepeatedLogs', () {
    test('groupRepeatedLogs: true groups consecutive identical logs', () {
      final controller = DebugKitController();
      controller.init(enabled: true, groupRepeatedLogs: true);

      controller.info('Retrying request');
      controller.info('Retrying request');
      controller.info('Retrying request');

      expect(controller.store.logs.length, 1);
      expect(controller.store.logs.first.repeatCount, 3);
    });

    test('groupRepeatedLogs: false stores all duplicates as separate entries',
        () {
      final controller = DebugKitController();
      controller.init(enabled: true, groupRepeatedLogs: false);

      controller.info('Retrying request');
      controller.info('Retrying request');
      controller.info('Retrying request');

      expect(controller.store.logs.length, 3);
      for (final entry in controller.store.logs) {
        expect(entry.repeatCount, 1);
      }
    });

    test('disabled mode still stores nothing regardless of grouping setting',
        () {
      final controller = DebugKitController();
      controller.init(enabled: false, groupRepeatedLogs: true);

      controller.info('Retrying request');
      controller.info('Retrying request');

      expect(controller.store.logs.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Export formatter — grouped entries
  // ---------------------------------------------------------------------------
  group('DebugLogExportFormatter with grouped entries', () {
    test('grouped entry includes ×N in header', () {
      final entry = DebugLogEntry(
        id: 1,
        level: DebugLogLevel.warning,
        source: DebugLogSource.app,
        message: 'Retrying request',
        timestamp: DateTime(2026, 6, 16, 14, 21, 2),
        repeatCount: 12,
        lastSeenAt: DateTime(2026, 6, 16, 14, 21, 9),
      );
      final formatted = DebugLogExportFormatter.formatEntry(entry);
      expect(formatted, contains('×12'));
      expect(formatted, contains('Message: Retrying request'));
    });

    test('grouped entry includes First seen and Last seen', () {
      final first = DateTime(2026, 6, 16, 14, 21, 2);
      final last = DateTime(2026, 6, 16, 14, 21, 9);
      final entry = DebugLogEntry(
        id: 1,
        level: DebugLogLevel.info,
        source: DebugLogSource.app,
        message: 'Poll tick',
        timestamp: first,
        repeatCount: 5,
        lastSeenAt: last,
      );
      final formatted = DebugLogExportFormatter.formatEntry(entry);
      expect(formatted, contains('First seen:'));
      expect(formatted, contains('Last seen :'));
    });

    test('non-grouped entry does not include First/Last seen or ×N', () {
      final entry = DebugLogEntry(
        id: 1,
        level: DebugLogLevel.info,
        source: DebugLogSource.app,
        message: 'Hello',
        timestamp: DateTime.now(),
      );
      final formatted = DebugLogExportFormatter.formatEntry(entry);
      expect(formatted, isNot(contains('×')));
      expect(formatted, isNot(contains('First seen')));
      expect(formatted, isNot(contains('Last seen')));
    });

    test('grouped entry does NOT expand into N duplicate lines', () {
      final entry = DebugLogEntry(
        id: 1,
        level: DebugLogLevel.info,
        source: DebugLogSource.app,
        message: 'Retrying',
        timestamp: DateTime.now(),
        repeatCount: 50,
        lastSeenAt: DateTime.now(),
      );
      final formatted = DebugLogExportFormatter.formatLogs([entry]);
      // Should appear exactly once in the output
      expect('Message: Retrying'.allMatches(formatted).length, 1);
      expect(formatted, contains('Total   : 1 entries'));
    });

    test('export does not contain raw fake secrets', () {
      final controller = DebugKitController();
      controller.init(enabled: true, groupRepeatedLogs: true);

      for (var i = 0; i < 3; i++) {
        controller.info('token is: abc123secret');
      }

      final logs = controller.store.logs.toList();
      final formatted = DebugLogExportFormatter.formatLogs(logs);
      expect(formatted, isNot(contains('abc123secret')));
      expect(formatted, contains('×3'));
    });
  });
}
