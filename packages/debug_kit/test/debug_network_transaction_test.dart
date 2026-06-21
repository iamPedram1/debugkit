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
    test('handles normal, missing, pending, and zero-duration requests', () {
      final built = DebugNetworkTransactionBuilder.build([
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/a',
          phase: 'completed',
          status: 200,
          durationMs: 0,
          timestamp: DateTime(2026, 1, 1, 12, 0, 1),
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/b',
          phase: 'pending',
          timestamp: DateTime(2026, 1, 1, 12, 0, 2),
        ),
        _networkEntry(
          id: 3,
          method: 'GET',
          path: '/c',
          phase: 'completed',
          status: 200,
          durationMs: 250,
          timestamp: DateTime(2026, 1, 1, 12, 0, 3),
        ),
      ]);

      final metrics = DebugNetworkWaterfallMetrics.fromTransactions(built);
      expect(metrics.rows, hasLength(3));
      expect(metrics.windowMs, greaterThan(0));
      expect(metrics.rows.first.barWidthFraction, greaterThan(0));
      expect(metrics.rows[1].isPending, isTrue);
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
