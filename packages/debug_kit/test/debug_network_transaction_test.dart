import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/utils/export/debug_log_export_formatter.dart';
import 'package:debug_kit/src/utils/filtering/debug_network_filter.dart';
import 'package:debug_kit/src/utils/network/debug_network_transaction_builder.dart';
import 'package:debug_kit/src/utils/network/debug_network_waterfall.dart';
import 'package:flutter_test/flutter_test.dart';

DebugLogEntry _networkEntry({
  required int id,
  required String method,
  required String path,
  required String phase,
  int? status,
  int? durationMs,
  String? requestId,
  String? traceId,
  String? traceName,
  String? errorType,
  String? errorMessage,
  String? url,
  String? query,
  String? host,
  String? stackTrace,
  Map<String, String>? extraMetadata,
  DateTime? timestamp,
  DebugLogLevel level = DebugLogLevel.info,
  String? requestHeadersPreview,
  String? responseHeadersPreview,
  String? requestBodyPreview,
  String? responseBodyPreview,
}) {
  return DebugLogEntry(
    id: id,
    level: level,
    source: DebugLogSource.dio,
    message: '$method $path',
    timestamp: timestamp ?? DateTime(2026, 1, 1, 12, 0, id),
    error: errorMessage,
    stackTrace: stackTrace,
    requestId: requestId,
    traceId: traceId,
    traceName: traceName,
    metadata: {
      'kind': 'networkTransaction',
      'method': method,
      'path': path,
      'phase': phase,
      if (status != null) 'status': '$status',
      if (durationMs != null) 'duration_ms': '$durationMs',
      if (durationMs != null) 'durationMs': '$durationMs',
      if (url != null) 'sanitizedUrl': url,
      if (url != null) 'url': url,
      if (query != null) 'query': query,
      if (host != null) 'host': host,
      if (errorType != null) 'errorType': errorType,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (requestHeadersPreview != null)
        'requestHeadersPreview': requestHeadersPreview,
      if (responseHeadersPreview != null)
        'responseHeadersPreview': responseHeadersPreview,
      if (requestBodyPreview != null) 'requestBodyPreview': requestBodyPreview,
      if (responseBodyPreview != null)
        'responseBodyPreview': responseBodyPreview,
      if (extraMetadata != null) ...extraMetadata,
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DebugNetworkTransactionBuilder', () {
    test('builds normalized transactions from sanitized logs', () {
      final transactions = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'get',
          path: '/feed?cursor=1',
          url: 'https://api.example.com/feed?cursor=1',
          host: 'api.example.com',
          query: 'cursor=1',
          phase: 'completed',
          status: 200,
          durationMs: 120,
          requestId: 'dio_1',
          traceId: 'trace_1',
          traceName: 'feed_flow',
          extraMetadata: {
            'backendRequestId': 'backend-req-1',
            'backendCorrelationId': 'backend-corr-1',
            'backendTraceId': 'backend-trace-1',
          },
        ),
      ]);

      expect(transactions, hasLength(1));
      final tx = transactions.single;
      expect(tx.method, 'GET');
      expect(tx.path, '/feed');
      expect(tx.query, 'cursor=1');
      expect(tx.host, 'api.example.com');
      expect(tx.displayPath, '/feed?cursor=1');
      expect(tx.statusCode, 200);
      expect(tx.statusFamily, DebugNetworkStatusFamily.twoXX);
      expect(tx.phase, DebugNetworkTransactionPhase.completed);
      expect(tx.isCompleted, isTrue);
      expect(tx.durationLabel, '120ms');
      expect(tx.requestId, 'dio_1');
      expect(tx.traceName, 'feed_flow');
      expect(tx.backendCorrelationId, 'backend-corr-1');
    });

    test('ignores malformed metadata safely', () {
      final transactions = DebugNetworkTransactionBuilder.build([
        DebugLogEntry(
          id: 1,
          level: DebugLogLevel.info,
          source: DebugLogSource.dio,
          message: 'Broken',
          timestamp: DateTime.now(),
          metadata: const {
            'kind': 'networkTransaction',
            'method': 'GET',
            'path': '',
            'phase': 'completed',
          },
        ),
      ]);

      expect(transactions, isEmpty);
    });
  });

  group('DebugNetworkFilterState', () {
    test('filters by method, status, phase, slow, and search', () {
      final transactions = [
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/feed',
          phase: 'completed',
          status: 200,
          durationMs: 120,
          requestId: 'dio_1',
        ),
        _networkEntry(
          id: 2,
          method: 'POST',
          path: '/auth/refresh',
          phase: 'failed',
          status: 401,
          durationMs: 900,
          requestId: 'dio_2',
          errorType: 'DioExceptionType.badResponse',
          errorMessage: 'Auth failed',
          traceId: 'trace_auth',
        ),
        _networkEntry(
          id: 3,
          method: 'GET',
          path: '/status',
          phase: 'pending',
          requestId: 'dio_3',
        ),
      ];
      final built = DebugNetworkTransactionBuilder.build(transactions);

      final filtered = applyNetworkFiltersAndSort(
        built,
        const DebugNetworkFilterState(
          methods: {'POST'},
          statuses: {DebugNetworkStatusFilter.failed},
          slowOnly: true,
          pendingOnly: false,
          slowThresholdMs: 500,
        ),
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.path, '/auth/refresh');

      final pendingFiltered = applyNetworkFiltersAndSort(
        built,
        const DebugNetworkFilterState(
            statuses: {DebugNetworkStatusFilter.pending}),
      );
      expect(pendingFiltered, hasLength(1));
      expect(pendingFiltered.single.isPending, isTrue);

      final searchFiltered = applyNetworkFiltersAndSort(
        built,
        const DebugNetworkFilterState(searchQuery: 'trace_auth'),
      );
      expect(searchFiltered, hasLength(1));
      expect(searchFiltered.single.traceId, 'trace_auth');
    });

    test('sorts newest first by default and honors duration/status/method/path',
        () {
      final built = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/a',
          phase: 'completed',
          status: 200,
          durationMs: 120,
          timestamp: DateTime(2026, 1, 1, 12, 0, 1),
        ),
        _networkEntry(
          id: 2,
          method: 'POST',
          path: '/b',
          phase: 'completed',
          status: 500,
          durationMs: 900,
          timestamp: DateTime(2026, 1, 1, 12, 0, 2),
        ),
        _networkEntry(
          id: 3,
          method: 'PATCH',
          path: '/c',
          phase: 'failed',
          status: 404,
          durationMs: 300,
          timestamp: DateTime(2026, 1, 1, 12, 0, 3),
        ),
      ]);

      expect(
        applyNetworkFiltersAndSort(
          built,
          const DebugNetworkFilterState(
              sortOption: DebugNetworkSortOption.newestFirst),
        ).map((e) => e.logEntryId),
        [3, 2, 1],
      );
      expect(
        applyNetworkFiltersAndSort(
          built,
          const DebugNetworkFilterState(
            sortOption: DebugNetworkSortOption.durationDescending,
          ),
        ).map((e) => e.logEntryId),
        [2, 3, 1],
      );
      expect(
        applyNetworkFiltersAndSort(
          built,
          const DebugNetworkFilterState(
            sortOption: DebugNetworkSortOption.statusAscending,
          ),
        ).map((e) => e.logEntryId),
        [1, 3, 2],
      );
      expect(
        applyNetworkFiltersAndSort(
          built,
          const DebugNetworkFilterState(
            sortOption: DebugNetworkSortOption.methodAscending,
          ),
        ).map((e) => e.method),
        ['GET', 'PATCH', 'POST'],
      );
      expect(
        applyNetworkFiltersAndSort(
          built,
          const DebugNetworkFilterState(
            sortOption: DebugNetworkSortOption.pathAscending,
          ),
        ).map((e) => e.path),
        ['/a', '/b', '/c'],
      );
    });
  });

  group('DebugNetworkWaterfallMetrics', () {
    test('empty transactions return safe metrics', () {
      final generatedAt = DateTime(2026, 1, 1, 12, 0);
      final metrics = DebugNetworkWaterfallMetrics.fromTransactions([],
          generatedAt: generatedAt);

      expect(metrics.rows, isEmpty);
      expect(metrics.windowStart,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
      expect(metrics.windowEnd,
          DateTime.fromMillisecondsSinceEpoch(1, isUtc: true));
      expect(metrics.windowMs, 1);
      expect(metrics.generatedAt, generatedAt);
      expect(metrics.hasMeaningfulTiming, isFalse);
    });

    test('completed transactions compute a shared window correctly', () {
      final built = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/a',
          phase: 'completed',
          status: 200,
          durationMs: 100,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 0),
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/b',
          phase: 'completed',
          status: 200,
          durationMs: 250,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 50),
        ),
      ]);

      final metrics = DebugNetworkWaterfallMetrics.fromTransactions(
        built,
        generatedAt: DateTime(2026, 1, 1, 12, 0, 1),
      );

      expect(metrics.windowStart, DateTime(2026, 1, 1, 12, 0, 0));
      expect(metrics.windowEnd, DateTime(2026, 1, 1, 12, 0, 0, 300));
      expect(metrics.windowMs, 300);

      final first = metrics.rowByLogEntryId(1)!;
      final second = metrics.rowByLogEntryId(2)!;

      expect(first.startOffsetMs, 0);
      expect(first.endOffsetMs, 100);
      expect(first.durationMs, 100);
      expect(first.barStartFraction, closeTo(0.0, 0.0001));
      expect(first.barWidthFraction, closeTo(100 / 300, 0.0001));

      expect(second.startOffsetMs, 50);
      expect(second.endOffsetMs, 300);
      expect(second.durationMs, 250);
      expect(second.barStartFraction, closeTo(50 / 300, 0.0001));
      expect(second.barWidthFraction, closeTo(250 / 300, 0.0001));
      expect(second.barStartFraction + second.barWidthFraction,
          lessThanOrEqualTo(1.0));
    });

    test('pending transactions extend to the generated timestamp', () {
      final built = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/pending',
          phase: 'pending',
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 100),
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/done',
          phase: 'completed',
          status: 200,
          durationMs: 25,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 0),
        ),
      ]);

      final generatedAt = DateTime(2026, 1, 1, 12, 0, 0, 400);
      final metrics = DebugNetworkWaterfallMetrics.fromTransactions(
        built,
        generatedAt: generatedAt,
      );

      final pending = metrics.rowByLogEntryId(1)!;
      expect(metrics.windowEnd, generatedAt);
      expect(pending.isPending, isTrue);
      expect(pending.isEstimated, isTrue);
      expect(pending.endOffsetMs, 400);
      expect(pending.durationMs, 300);
      expect(pending.durationLabel, '300ms');
      expect(pending.timingLabel, '+100ms · pending');
    });

    test('zero-duration and very fast requests keep accurate labels', () {
      final built = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/zero',
          phase: 'completed',
          status: 200,
          durationMs: 0,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/fast',
          phase: 'completed',
          status: 200,
          durationMs: 1,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 10),
        ),
        _networkEntry(
          id: 3,
          method: 'GET',
          path: '/slow',
          phase: 'completed',
          status: 200,
          durationMs: 100,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 20),
        ),
      ]);

      final metrics = DebugNetworkWaterfallMetrics.fromTransactions(
        built,
        generatedAt: DateTime(2026, 1, 1, 12, 0, 1),
      );

      final zero = metrics.rowByLogEntryId(1)!;
      final fast = metrics.rowByLogEntryId(2)!;

      expect(zero.durationLabel, '0ms');
      expect(zero.renderBarWidthFraction(0.06), closeTo(0.06, 0.0001));
      expect(fast.durationLabel, '1ms');
      expect(fast.renderBarWidthFraction(0.06),
          greaterThan(fast.barWidthFraction));
      expect(fast.timingLabel, '+10ms · 1ms');
    });

    test('missing duration and completion data are handled safely', () {
      final built = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/unknown',
          phase: 'completed',
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
        ),
      ]);

      final metrics = DebugNetworkWaterfallMetrics.fromTransactions(
        built,
        generatedAt: DateTime(2026, 1, 1, 12, 0, 1),
      );

      final row = metrics.rowByLogEntryId(1)!;
      expect(row.isEstimated, isTrue);
      expect(row.durationMs, 0);
      expect(row.durationLabel, 'unknown');
      expect(row.barWidthFraction, 0);
      expect(row.renderBarWidthFraction(0.06), closeTo(0.06, 0.0001));
    });

    test('rows can be looked up by transaction and logEntryId', () {
      final built = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/first',
          phase: 'completed',
          status: 200,
          durationMs: 30,
          requestId: 'req-1',
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/second',
          phase: 'completed',
          status: 200,
          durationMs: 60,
          requestId: 'req-2',
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 40),
        ),
      ]);

      final reversed = built.reversed.toList(growable: false);
      final metrics = DebugNetworkWaterfallMetrics.fromTransactions(
        reversed,
        generatedAt: DateTime(2026, 1, 1, 12, 0, 1),
      );

      final tx = reversed.firstWhere((tx) => tx.logEntryId == 1);
      expect(metrics.rowByLogEntryId(1)?.transaction.logEntryId, 1);
      expect(metrics.rowForTransaction(tx)?.transaction.requestId, 'req-1');
    });

    test('sorting and filtering do not break row lookup', () {
      final built = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/a',
          phase: 'completed',
          status: 200,
          durationMs: 300,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/b',
          phase: 'completed',
          status: 200,
          durationMs: 50,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 20),
        ),
        _networkEntry(
          id: 3,
          method: 'POST',
          path: '/c',
          phase: 'completed',
          status: 201,
          durationMs: 150,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 40),
        ),
      ]);

      final filtered = applyNetworkFiltersAndSort(
        built,
        const DebugNetworkFilterState(
          sortOption: DebugNetworkSortOption.durationAscending,
          methods: {'GET', 'POST'},
        ),
      );
      final metrics = DebugNetworkWaterfallMetrics.fromTransactions(
        filtered,
        generatedAt: DateTime(2026, 1, 1, 12, 0, 1),
      );

      expect(filtered.map((tx) => tx.logEntryId), [2, 3, 1]);
      for (final tx in filtered) {
        expect(metrics.rowForTransaction(tx)?.transaction.logEntryId,
            tx.logEntryId);
      }
    });

    test('fractions stay clamped and rows share the same visible window', () {
      final built = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/a',
          phase: 'completed',
          status: 200,
          durationMs: 40,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/b',
          phase: 'completed',
          status: 200,
          durationMs: 400,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 20),
        ),
        _networkEntry(
          id: 3,
          method: 'GET',
          path: '/c',
          phase: 'completed',
          status: 200,
          durationMs: 5,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 30),
        ),
      ]);

      final metrics = DebugNetworkWaterfallMetrics.fromTransactions(
        built,
        generatedAt: DateTime(2026, 1, 1, 12, 0, 1),
      );

      for (final row in metrics.rows) {
        expect(row.barStartFraction, inInclusiveRange(0.0, 1.0));
        expect(row.barWidthFraction, inInclusiveRange(0.0, 1.0));
        expect(row.barStartFraction + row.barWidthFraction,
            lessThanOrEqualTo(1.0));
      }
      expect(metrics.rows.map((row) => row.transaction.startedAt),
          everyElement(isA<DateTime>()));
      expect(metrics.rows.map((row) => row.transaction.logEntryId),
          unorderedEquals([1, 2, 3]));
    });

    test('timeline labels are human-readable and flags are preserved', () {
      final built = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/pending',
          phase: 'pending',
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 20),
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/failed',
          phase: 'failed',
          status: 500,
          durationMs: 90,
          errorType: 'DioExceptionType.badResponse',
          errorMessage: 'Server exploded',
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
        ),
      ]);

      final metrics = DebugNetworkWaterfallMetrics.fromTransactions(
        built,
        generatedAt: DateTime(2026, 1, 1, 12, 0, 0, 200),
      );

      final pending = metrics.rowByLogEntryId(1)!;
      final failed = metrics.rowByLogEntryId(2)!;

      expect(pending.startOffsetLabel, '+20ms');
      expect(pending.timingLabel, contains('pending'));
      expect(failed.transaction.isFailed, isTrue);
      expect(failed.transaction.isPending, isFalse);
      expect(failed.durationLabel, '90ms');
    });
  });

  group('DebugNetworkTimelineViewport', () {
    test('defaults to a full, unclamped range', () {
      final viewport = DebugNetworkTimelineViewport.full();

      expect(viewport.rangeStartFraction, 0);
      expect(viewport.rangeEndFraction, 1);
      expect(viewport.selectedLogEntryId, isNull);
      expect(viewport.isFull, isTrue);
    });

    test('selected request id does not affect full-range state', () {
      final viewport = DebugNetworkTimelineViewport.full(
        selectedLogEntryId: 42,
      );

      expect(viewport.isFull, isTrue);
      expect(viewport.selectedLogEntryId, 42);
    });

    test('clearing selection keeps the current time range', () {
      const viewport = DebugNetworkTimelineViewport(
        rangeStartFraction: 0.2,
        rangeEndFraction: 0.6,
        selectedLogEntryId: 7,
      );

      final cleared = viewport.clearSelection();

      expect(cleared.rangeStartFraction, viewport.rangeStartFraction);
      expect(cleared.rangeEndFraction, viewport.rangeEndFraction);
      expect(cleared.selectedLogEntryId, isNull);
      expect(cleared.isFull, isFalse);
    });

    test('normalizes and clamps to bounds with minimum width', () {
      final viewport = const DebugNetworkTimelineViewport(
        rangeStartFraction: -0.2,
        rangeEndFraction: 0.01,
      ).normalized(minRangeFraction: 0.1);

      expect(viewport.rangeStartFraction, 0);
      expect(viewport.rangeEndFraction, closeTo(0.1, 0.0001));
      expect(viewport.rangeDurationMs(1000), 100);
    });

    test('moving a range preserves width and clamps to the window', () {
      const viewport = DebugNetworkTimelineViewport(
        rangeStartFraction: 0.2,
        rangeEndFraction: 0.4,
      );

      final moved = viewport.moveByFraction(0.5);

      expect(moved.rangeEndFraction - moved.rangeStartFraction,
          closeTo(0.2, 0.0001));
      expect(moved.rangeStartFraction, closeTo(0.7, 0.0001));
      expect(moved.rangeEndFraction, closeTo(0.9, 0.0001));

      final clamped = viewport.moveByFraction(0.9);
      expect(clamped.rangeEndFraction, 1);
      expect(clamped.rangeStartFraction, closeTo(0.8, 0.0001));
    });

    test('resizing handles enforces the minimum width', () {
      const viewport = DebugNetworkTimelineViewport(
        rangeStartFraction: 0.2,
        rangeEndFraction: 0.5,
      );

      final resizedLeft = viewport.resizeLeftToFraction(0.48);
      expect(resizedLeft.rangeEndFraction - resizedLeft.rangeStartFraction,
          closeTo(0.05, 0.0001));
      expect(resizedLeft.rangeStartFraction, closeTo(0.45, 0.0001));

      final resizedRight = viewport.resizeRightToFraction(0.21);
      expect(resizedRight.rangeEndFraction - resizedRight.rangeStartFraction,
          closeTo(0.05, 0.0001));
      expect(resizedRight.rangeEndFraction, closeTo(0.25, 0.0001));
    });

    test('range labels are human-readable', () {
      const viewport = DebugNetworkTimelineViewport(
        rangeStartFraction: 0.1,
        rangeEndFraction: 0.35,
      );

      expect(viewport.rangeLabel(1000), '100ms → 350ms');
      expect(viewport.durationLabel(1000), 'Range: 250ms');
      expect(viewport.rangeStartMs(1000), 100);
      expect(viewport.rangeEndMs(1000), 350);
    });

    test('row intersection respects the selected time range', () {
      final built = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/a',
          phase: 'completed',
          status: 200,
          durationMs: 100,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/b',
          phase: 'completed',
          status: 200,
          durationMs: 100,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0, 300),
        ),
      ]);

      final metrics = DebugNetworkWaterfallMetrics.fromTransactions(
        built,
        generatedAt: DateTime(2026, 1, 1, 12, 0, 1),
      );
      const viewport = DebugNetworkTimelineViewport(
        rangeStartFraction: 0.0,
        rangeEndFraction: 0.25,
      );

      final first = metrics.rowByLogEntryId(1)!;
      final second = metrics.rowByLogEntryId(2)!;

      expect(viewport.intersectsRow(first, metrics.windowMs), isTrue);
      expect(viewport.intersectsRow(second, metrics.windowMs), isFalse);
    });
  });

  group('DebugLogExportFormatter', () {
    test('includes a network request list and keeps secrets masked', () {
      final controller = DebugKitController();
      controller.init(enabled: true);
      controller.log(
        message: 'token is: abc123secret',
        level: DebugLogLevel.info,
        source: DebugLogSource.app,
      );
      controller.store.addLog(
        _networkEntry(
          id: 20,
          method: 'GET',
          path: '/profile',
          phase: 'completed',
          status: 200,
          durationMs: 90,
          requestId: 'dio_20',
          traceId: 'trace_20',
          extraMetadata: const {
            'backendCorrelationId': 'backend-corr-20',
          },
          stackTrace: '#0 fetchProfile (profile.dart:10)',
          requestHeadersPreview: 'Authorization: ***',
          responseHeadersPreview: 'content-type: application/json',
          requestBodyPreview: '{"name":"John"}',
          responseBodyPreview: '{"id":1}',
        ),
      );

      final formatted = DebugLogExportFormatter.formatLogs(
        controller.store.logs.toList(),
      );

      expect(formatted, contains('Network Requests'));
      expect(formatted, contains('GET /profile'));
      expect(formatted, contains('backend-corr-20'));
      expect(formatted, isNot(contains('abc123secret')));
      expect(formatted, contains('ab********et'));
    });
  });

  group('DebugKitController selective clearing', () {
    test('clearNetworkTransactions removes only network entries', () {
      final controller = DebugKitController();
      controller.init(enabled: true);
      controller.info('app log');
      controller.store.addLog(
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/feed',
          phase: 'completed',
          status: 200,
          durationMs: 100,
        ),
      );

      final removed = controller.clearNetworkTransactions();

      expect(removed, 1);
      expect(controller.store.logs, hasLength(1));
      expect(controller.store.logs.single.source, DebugLogSource.app);
    });
  });
}
