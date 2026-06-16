import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/core/store/debug_trace_store.dart';
import 'package:debug_kit/src/utils/trace/debug_trace_analyzer.dart';
import 'package:debug_kit/src/utils/export/debug_trace_export_formatter.dart';
import 'package:debug_kit/src/utils/export/debug_log_export_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // DebugTraceStore
  // ---------------------------------------------------------------------------
  group('DebugTraceStore', () {
    late DebugTraceStore store;

    setUp(() {
      store = DebugTraceStore(maxTraces: 5, maxEventsPerTrace: 3);
    });

    test('starts a trace and stores it', () {
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'login_flow',
        status: DebugTraceStatus.running,
        startedAt: DateTime.now(),
      );
      store.startTrace(trace);
      expect(store.traces.length, 1);
      expect(store.traces.first.name, 'login_flow');
      expect(store.traces.first.status, DebugTraceStatus.running);
    });

    test('finishTrace marks trace as success', () {
      final now = DateTime.now();
      store.startTrace(DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.running,
        startedAt: now,
      ));
      store.finishTrace('trace_1', now.add(const Duration(milliseconds: 100)));
      expect(store.traces.first.status, DebugTraceStatus.success);
      expect(store.traces.first.endedAt, isNotNull);
    });

    test('failTrace marks trace as failed with error summary', () {
      final now = DateTime.now();
      store.startTrace(DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.running,
        startedAt: now,
      ));
      store.failTrace('trace_1', now.add(const Duration(milliseconds: 50)),
          errorSummary: 'Auth failed');
      expect(store.traces.first.status, DebugTraceStatus.failed);
      expect(store.traces.first.errorSummary, 'Auth failed');
    });

    test('cancelTrace marks trace as cancelled', () {
      final now = DateTime.now();
      store.startTrace(DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.running,
        startedAt: now,
      ));
      store.cancelTrace('trace_1', now.add(const Duration(milliseconds: 10)));
      expect(store.traces.first.status, DebugTraceStatus.cancelled);
    });

    test('addEvent appends event to running trace', () {
      final now = DateTime.now();
      store.startTrace(DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.running,
        startedAt: now,
      ));
      store.addEvent(
        'trace_1',
        DebugTraceEvent(
          id: 'evt_1',
          traceId: 'trace_1',
          message: 'step one',
          type: DebugTraceEventType.step,
          timestamp: now,
        ),
      );
      expect(store.traces.first.events.length, 1);
      expect(store.traces.first.events.first.message, 'step one');
    });

    test('addEvent ignores events for finished traces', () {
      final now = DateTime.now();
      store.startTrace(DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.running,
        startedAt: now,
      ));
      store.finishTrace('trace_1', now);
      store.addEvent(
        'trace_1',
        DebugTraceEvent(
          id: 'evt_1',
          traceId: 'trace_1',
          message: 'late event',
          type: DebugTraceEventType.step,
          timestamp: now,
        ),
      );
      expect(store.traces.first.events.length, 0);
    });

    test('enforces maxEventsPerTrace by dropping oldest', () {
      final now = DateTime.now();
      store.startTrace(DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.running,
        startedAt: now,
      ));
      for (var i = 1; i <= 5; i++) {
        store.addEvent(
          'trace_1',
          DebugTraceEvent(
            id: 'evt_$i',
            traceId: 'trace_1',
            message: 'event $i',
            type: DebugTraceEventType.step,
            timestamp: now,
          ),
        );
      }
      // maxEventsPerTrace = 3, so only last 3 remain
      expect(store.traces.first.events.length, 3);
      expect(store.traces.first.events.first.message, 'event 3');
      expect(store.traces.first.events.last.message, 'event 5');
    });

    test('evicts oldest completed trace when maxTraces reached', () {
      for (var i = 1; i <= 5; i++) {
        final t = DebugTrace(
          id: 'trace_$i',
          name: 'flow_$i',
          status: DebugTraceStatus.success,
          startedAt: DateTime.now(),
          endedAt: DateTime.now(),
        );
        store.startTrace(t);
      }
      expect(store.traces.length, 5);
      // Adding a 6th should evict the oldest completed
      store.startTrace(DebugTrace(
        id: 'trace_6',
        name: 'flow_6',
        status: DebugTraceStatus.running,
        startedAt: DateTime.now(),
      ));
      expect(store.traces.length, 5);
      expect(store.traces.any((t) => t.id == 'trace_1'), isFalse);
      expect(store.traces.any((t) => t.id == 'trace_6'), isTrue);
    });

    test('clear removes all traces', () {
      store.startTrace(DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.running,
        startedAt: DateTime.now(),
      ));
      store.clear();
      expect(store.traces.isEmpty, isTrue);
    });

    test('activeTrace returns the last running trace', () {
      store.startTrace(DebugTrace(
        id: 'trace_1',
        name: 'flow_1',
        status: DebugTraceStatus.running,
        startedAt: DateTime.now(),
      ));
      store.startTrace(DebugTrace(
        id: 'trace_2',
        name: 'flow_2',
        status: DebugTraceStatus.running,
        startedAt: DateTime.now(),
      ));
      expect(store.activeTrace?.id, 'trace_2');
    });
  });

  // ---------------------------------------------------------------------------
  // DebugTraceController
  // ---------------------------------------------------------------------------
  group('DebugTraceController', () {
    late DebugTraceStore store;
    late DebugTraceController controller;

    setUp(() {
      store = DebugTraceStore(maxTraces: 10, maxEventsPerTrace: 50);
      controller = DebugTraceController(
        store: store,
        isEnabled: () => true,
      );
    });

    test('start creates a running trace and returns non-empty id', () {
      final id = controller.start('login_flow');
      expect(id, isNotEmpty);
      expect(store.traces.length, 1);
      expect(store.traces.first.status, DebugTraceStatus.running);
      expect(store.traces.first.name, 'login_flow');
    });

    test('step adds a step event to the trace', () {
      final id = controller.start('flow');
      controller.step('validate_input', traceId: id);
      expect(store.traces.first.events.length, 1);
      expect(store.traces.first.events.first.type, DebugTraceEventType.step);
      expect(store.traces.first.events.first.message, 'validate_input');
    });

    test('end marks trace as success', () {
      final id = controller.start('flow');
      controller.end(traceId: id);
      expect(store.traces.first.status, DebugTraceStatus.success);
      expect(store.traces.first.endedAt, isNotNull);
    });

    test('fail marks trace as failed with sanitized error', () {
      final id = controller.start('flow');
      controller.fail('Auth failed: token=secret123', null, traceId: id);
      expect(store.traces.first.status, DebugTraceStatus.failed);
      expect(store.traces.first.errorSummary, isNotNull);
      // Secret should be masked
      expect(store.traces.first.errorSummary, isNot(contains('secret123')));
    });

    test('cancel marks trace as cancelled', () {
      final id = controller.start('flow');
      controller.cancel('user_cancelled', traceId: id);
      expect(store.traces.first.status, DebugTraceStatus.cancelled);
    });

    test('metadata is sanitized on start', () {
      controller.start('flow', metadata: {'api_key': 'abc123secret'});
      // abc123secret is 12 chars → ab********et
      expect(store.traces.first.metadata?['api_key'], 'ab********et');
    });
  });

  // ---------------------------------------------------------------------------
  // DebugTraceController — disabled mode
  // ---------------------------------------------------------------------------
  group('DebugTraceController disabled mode', () {
    test('start returns empty string and stores nothing', () {
      final store = DebugTraceStore();
      final controller = DebugTraceController(
        store: store,
        isEnabled: () => false,
      );
      final id = controller.start('flow');
      expect(id, isEmpty);
      expect(store.traces.isEmpty, isTrue);
    });

    test('step, end, fail, cancel are all no-ops', () {
      final store = DebugTraceStore();
      final controller = DebugTraceController(
        store: store,
        isEnabled: () => false,
      );
      expect(() => controller.step('step', traceId: 'x'), returnsNormally);
      expect(() => controller.end(traceId: 'x'), returnsNormally);
      expect(() => controller.fail('err', null, traceId: 'x'), returnsNormally);
      expect(() => controller.cancel('reason', traceId: 'x'), returnsNormally);
      expect(store.traces.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // DebugTraceController — run() scoped API
  // ---------------------------------------------------------------------------
  group('DebugTraceController.run()', () {
    late DebugTraceStore store;
    late DebugTraceController controller;

    setUp(() {
      store = DebugTraceStore(maxTraces: 10, maxEventsPerTrace: 50);
      controller = DebugTraceController(
        store: store,
        isEnabled: () => true,
      );
    });

    test('run marks trace as success on normal completion', () async {
      await controller.run('login_flow', () async {
        await Future.delayed(Duration.zero);
      });
      expect(store.traces.length, 1);
      expect(store.traces.first.status, DebugTraceStatus.success);
      expect(store.traces.first.endedAt, isNotNull);
    });

    test('run marks trace as failed and rethrows on exception', () async {
      Object? caught;
      try {
        await controller.run('login_flow', () async {
          throw Exception('Auth failed');
        });
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught.toString(), contains('Auth failed'));
      expect(store.traces.first.status, DebugTraceStatus.failed);
    });

    test('run propagates trace ID via Zone', () async {
      String? capturedId;
      await controller.run('login_flow', () async {
        capturedId = Zone.current[debugKitActiveTraceIdKey] as String?;
      });
      expect(capturedId, isNotNull);
      expect(capturedId, isNotEmpty);
      expect(store.traces.first.id, capturedId);
    });

    test('run propagates trace name via Zone', () async {
      String? capturedName;
      await controller.run('login_flow', () async {
        capturedName = Zone.current[debugKitActiveTraceNameKey] as String?;
      });
      expect(capturedName, 'login_flow');
    });

    test('nested run creates child trace with parentTraceId', () async {
      await controller.run('outer', () async {
        await controller.run('inner', () async {
          await Future.delayed(Duration.zero);
        });
      });
      expect(store.traces.length, 2);
      final inner = store.traces.firstWhere((t) => t.name == 'inner');
      final outer = store.traces.firstWhere((t) => t.name == 'outer');
      expect(inner.parentTraceId, outer.id);
    });

    test('run is no-op when disabled — callback still executes', () async {
      final disabledStore = DebugTraceStore();
      final disabledController = DebugTraceController(
        store: disabledStore,
        isEnabled: () => false,
      );
      var executed = false;
      await disabledController.run('flow', () async {
        executed = true;
      });
      expect(executed, isTrue);
      expect(disabledStore.traces.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Log correlation with active trace
  // ---------------------------------------------------------------------------
  group('Log correlation with active trace', () {
    test('logs inside run() carry traceId and traceName', () async {
      final controller = DebugKitController();
      controller.init(enabled: true);

      await controller.traceController.run('login_flow', () async {
        controller.info('Inside trace');
      });

      final logs = controller.store.logs.toList();
      expect(logs.isNotEmpty, isTrue);
      final traceLog = logs.firstWhere((l) => l.message == 'Inside trace');
      expect(traceLog.traceId, isNotNull);
      expect(traceLog.traceName, 'login_flow');
    });

    test('logs outside run() have no traceId', () {
      final controller = DebugKitController();
      controller.init(enabled: true);
      controller.info('Outside trace');
      final log = controller.store.logs.last;
      expect(log.traceId, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // DebugTraceAnalyzer
  // ---------------------------------------------------------------------------
  group('DebugTraceAnalyzer', () {
    test('no warnings for healthy completed trace', () {
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.success,
        startedAt: DateTime.now().subtract(const Duration(milliseconds: 500)),
        endedAt: DateTime.now(),
      );
      expect(DebugTraceAnalyzer.analyze(trace), isEmpty);
    });

    test('warns on failed trace', () {
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.failed,
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        errorSummary: 'Auth failed',
      );
      final warnings = DebugTraceAnalyzer.analyze(trace);
      expect(warnings.any((w) => w.contains('trace failed')), isTrue);
    });

    test('warns on cancelled trace', () {
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.cancelled,
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
      );
      final warnings = DebugTraceAnalyzer.analyze(trace);
      expect(warnings.any((w) => w.contains('cancelled')), isTrue);
    });

    test('warns on slow trace', () {
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.success,
        startedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        endedAt: DateTime.now(),
      );
      final warnings = DebugTraceAnalyzer.analyze(
        trace,
        slowThreshold: const Duration(seconds: 3),
      );
      expect(warnings.any((w) => w.contains('slow trace')), isTrue);
    });

    test('warns on failed network events inside trace', () {
      final now = DateTime.now();
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.success,
        startedAt: now,
        endedAt: now,
        events: [
          DebugTraceEvent(
            id: 'evt_1',
            traceId: 'trace_1',
            message: 'GET /api/login failed',
            type: DebugTraceEventType.network,
            timestamp: now,
            error: '401 Unauthorized',
          ),
        ],
      );
      final warnings = DebugTraceAnalyzer.analyze(trace);
      expect(warnings.any((w) => w.contains('failed network')), isTrue);
    });

    test('warns on high event count', () {
      final now = DateTime.now();
      final events = List.generate(
        101,
        (i) => DebugTraceEvent(
          id: 'evt_$i',
          traceId: 'trace_1',
          message: 'event $i',
          type: DebugTraceEventType.step,
          timestamp: now,
        ),
      );
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.success,
        startedAt: now,
        endedAt: now,
        events: events,
      );
      final warnings = DebugTraceAnalyzer.analyze(trace);
      expect(warnings.any((w) => w.contains('high event count')), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // DebugTraceExportFormatter
  // ---------------------------------------------------------------------------
  group('DebugTraceExportFormatter', () {
    test('formats empty trace list', () {
      final output = DebugTraceExportFormatter.formatTraces([]);
      expect(output, contains('Total: 0'));
    });

    test('formats a successful trace', () {
      final now = DateTime.now();
      final trace = DebugTrace(
        id: 'trace_abc',
        name: 'login_flow',
        status: DebugTraceStatus.success,
        startedAt: now,
        endedAt: now.add(const Duration(milliseconds: 842)),
      );
      final output = DebugTraceExportFormatter.formatTrace(trace);
      expect(output, contains('login_flow'));
      expect(output, contains('trace_abc'));
      expect(output, contains('SUCCESS'));
      expect(output, contains('842ms'));
    });

    test('formats a failed trace with error summary', () {
      final now = DateTime.now();
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'auth_flow',
        status: DebugTraceStatus.failed,
        startedAt: now,
        endedAt: now,
        errorSummary: 'Auth failed',
      );
      final output = DebugTraceExportFormatter.formatTrace(trace);
      expect(output, contains('FAILED'));
      expect(output, contains('Auth failed'));
    });

    test('formats timeline events', () {
      final now = DateTime.now();
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.success,
        startedAt: now,
        endedAt: now,
        events: [
          DebugTraceEvent(
            id: 'evt_1',
            traceId: 'trace_1',
            message: 'validate_input',
            type: DebugTraceEventType.step,
            timestamp: now,
          ),
        ],
      );
      final output = DebugTraceExportFormatter.formatTrace(trace);
      expect(output, contains('Timeline'));
      expect(output, contains('validate_input'));
      expect(output, contains('STEP'));
    });

    test('formatFailedSummary returns empty string when no failures', () {
      final traces = [
        DebugTrace(
          id: 'trace_1',
          name: 'flow',
          status: DebugTraceStatus.success,
          startedAt: DateTime.now(),
        ),
      ];
      expect(DebugTraceExportFormatter.formatFailedSummary(traces), isEmpty);
    });

    test('metadata is not re-sanitized — stored values are preserved', () {
      final now = DateTime.now();
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'flow',
        status: DebugTraceStatus.success,
        startedAt: now,
        endedAt: now,
        metadata: {'api_key': 'ab********et'}, // already sanitized
      );
      final output = DebugTraceExportFormatter.formatTrace(trace);
      expect(output, contains('ab********et'));
      expect(output, isNot(contains('abc123secret')));
    });
  });

  // ---------------------------------------------------------------------------
  // Export formatter — combined logs + traces
  // ---------------------------------------------------------------------------
  group('DebugLogExportFormatter with traces', () {
    test('includes traces section when traces provided', () {
      final controller = DebugKitController();
      controller.init(enabled: true);
      controller.info('Test log');

      final now = DateTime.now();
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'login_flow',
        status: DebugTraceStatus.success,
        startedAt: now,
        endedAt: now,
      );

      final output = DebugLogExportFormatter.formatLogs(
        controller.store.logs.toList(),
        traces: [trace],
      );
      expect(output, contains('DebugKit Logs'));
      expect(output, contains('DebugKit Traces'));
      expect(output, contains('login_flow'));
    });

    test('does not include traces section when traces is null', () {
      final controller = DebugKitController();
      controller.init(enabled: true);
      controller.info('Test log');

      final output = DebugLogExportFormatter.formatLogs(
        controller.store.logs.toList(),
      );
      expect(output, isNot(contains('DebugKit Traces')));
    });

    test('raw secrets do not appear in combined export', () {
      final controller = DebugKitController();
      controller.init(enabled: true);
      controller.info('token is: abc123secret');

      final output = DebugLogExportFormatter.formatLogs(
        controller.store.logs.toList(),
      );
      expect(output, isNot(contains('abc123secret')));
    });
  });
}
