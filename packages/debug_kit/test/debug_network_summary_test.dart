import 'package:flutter_test/flutter_test.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/utils/export/debug_log_export_formatter.dart';
import 'package:debug_kit/src/utils/network/debug_network_summary_builder.dart';

DebugLogEntry _networkEntry({
  required int id,
  required String method,
  required String path,
  required String phase,
  int? status,
  int? durationMs,
  String? requestId,
  String? traceId,
  Map<String, String>? extraMetadata,
  DateTime? timestamp,
  DebugLogLevel level = DebugLogLevel.info,
}) {
  return DebugLogEntry(
    id: id,
    level: level,
    source: DebugLogSource.dio,
    message: '$method $path',
    timestamp: timestamp ?? DateTime(2026, 1, 1, 12, 0, id),
    requestId: requestId,
    traceId: traceId,
    metadata: {
      'kind': 'networkTransaction',
      'method': method,
      'path': path,
      'phase': phase,
      if (status != null) 'status': '$status',
      if (durationMs != null) 'duration_ms': '$durationMs',
      if (durationMs != null) 'durationMs': '$durationMs',
      if (extraMetadata != null) ...extraMetadata,
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DebugNetworkSummaryBuilder', () {
    test('returns empty summary for empty input', () {
      final summary = DebugNetworkSummaryBuilder.build(const []);
      expect(summary.isEmpty, isTrue);
      expect(summary.totalRequests, 0);
      expect(summary.statusBreakdown.statusUnknown, 0);
    });

    test('counts completed, failed, pending, and status buckets', () {
      final logs = [
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/feed',
          phase: 'completed',
          status: 200,
          durationMs: 120,
          requestId: 'dio_1',
          traceId: 'trace_1',
        ),
        _networkEntry(
          id: 2,
          method: 'POST',
          path: '/auth/refresh',
          phase: 'failed',
          status: 401,
          durationMs: 240,
          requestId: 'dio_2',
          traceId: 'trace_1',
        ),
        _networkEntry(
          id: 3,
          method: 'GET',
          path: '/status',
          phase: 'pending',
          requestId: 'dio_3',
          traceId: 'trace_1',
        ),
      ];

      final summary = DebugNetworkSummaryBuilder.build(logs);

      expect(summary.totalRequests, 3);
      expect(summary.completedRequests, 1);
      expect(summary.failedRequests, 1);
      expect(summary.pendingRequests, 1);
      expect(summary.slowRequests, 0);
      expect(summary.statusBreakdown.status2xx, 1);
      expect(summary.statusBreakdown.status4xx, 1);
      expect(summary.statusBreakdown.status3xx, 0);
      expect(summary.statusBreakdown.status5xx, 0);
      expect(summary.statusBreakdown.statusUnknown, 1);
      expect(summary.averageDurationMs, 180);
      expect(summary.maxDurationMs, 240);
      expect(summary.minDurationMs, 120);
      expect(summary.topFailingEndpoints.single.method, 'POST');
      expect(summary.topFailingEndpoints.single.path, '/auth/refresh');
    });

    test('slow request threshold marks slow endpoints', () {
      final logs = [
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/feed',
          phase: 'completed',
          status: 200,
          durationMs: 499,
          requestId: 'dio_1',
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/feed',
          phase: 'completed',
          status: 200,
          durationMs: 501,
          requestId: 'dio_2',
        ),
      ];

      final summary = DebugNetworkSummaryBuilder.build(
        logs,
        slowRequestThresholdMs: 500,
      );

      expect(summary.slowRequests, 1);
      expect(summary.slowestEndpoints.single.slowCount, 1);
      expect(summary.slowestEndpoints.single.maxDurationMs, 501);
    });

    test('groups endpoints by method and normalized path without query', () {
      final logs = [
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/feed?cursor=1',
          phase: 'completed',
          status: 200,
          durationMs: 100,
          requestId: 'dio_1',
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/feed?cursor=2',
          phase: 'completed',
          status: 200,
          durationMs: 120,
          requestId: 'dio_2',
        ),
      ];

      final summary = DebugNetworkSummaryBuilder.build(logs);

      expect(summary.totalRequests, 2);
      expect(summary.mostCalledEndpoints.single.path, '/feed');
      expect(summary.mostCalledEndpoints.single.totalCount, 2);
    });

    test('sorts failing and slow endpoints deterministically', () {
      final logs = [
        _networkEntry(
          id: 1,
          method: 'POST',
          path: '/auth/refresh',
          phase: 'failed',
          status: 500,
          durationMs: 900,
          requestId: 'dio_1',
        ),
        _networkEntry(
          id: 2,
          method: 'GET',
          path: '/feed',
          phase: 'failed',
          status: 404,
          durationMs: 300,
          requestId: 'dio_2',
        ),
        _networkEntry(
          id: 3,
          method: 'GET',
          path: '/feed',
          phase: 'failed',
          status: 404,
          durationMs: 280,
          requestId: 'dio_3',
        ),
      ];

      final summary = DebugNetworkSummaryBuilder.build(logs);

      expect(summary.topFailingEndpoints.first.path, '/feed');
      expect(summary.topFailingEndpoints.first.failedCount, 2);
      expect(summary.slowestEndpoints.first.path, '/auth/refresh');
    });

    test('ignores malformed metadata safely', () {
      final logs = [
        DebugLogEntry(
          id: 1,
          level: DebugLogLevel.info,
          source: DebugLogSource.dio,
          message: 'Broken network log',
          timestamp: DateTime.now(),
          metadata: {
            'kind': 'networkTransaction',
            'method': 'GET',
            'path': '',
            'phase': 'completed',
          },
        ),
      ];

      final summary = DebugNetworkSummaryBuilder.build(logs);
      expect(summary.isEmpty, isTrue);
    });

    test('collects request and trace IDs plus backend correlation metadata',
        () {
      final logs = [
        _networkEntry(
          id: 1,
          method: 'GET',
          path: '/profile',
          phase: 'completed',
          status: 200,
          durationMs: 90,
          requestId: 'dio_1',
          traceId: 'trace_42',
          extraMetadata: {
            'backendRequestId': 'backend-req-1',
            'backendCorrelationId': 'backend-corr-1',
            'backendTraceId': 'backend-trace-1',
          },
        ),
      ];

      final summary = DebugNetworkSummaryBuilder.build(logs);
      final endpoint = summary.mostCalledEndpoints.single;
      expect(endpoint.relatedRequestIds, ['dio_1']);
      expect(endpoint.relatedTraceIds, ['trace_42']);
      expect(endpoint.backendRequestIds, ['backend-req-1']);
      expect(endpoint.backendCorrelationIds, ['backend-corr-1']);
      expect(endpoint.backendTraceIds, ['backend-trace-1']);
    });
  });

  group('DebugLogExportFormatter network summary', () {
    test('includes network summary section', () {
      final logs = [
        _networkEntry(
          id: 1,
          method: 'POST',
          path: '/auth/refresh',
          phase: 'failed',
          status: 500,
          durationMs: 111,
          requestId: 'dio_1',
        ),
      ];
      final summary = DebugNetworkSummaryBuilder.build(logs);

      final formatted = DebugLogExportFormatter.formatLogs(
        logs,
        networkSummary: summary,
      );

      expect(formatted, contains('Network Summary'));
      expect(formatted, contains('Total     : 1'));
      expect(formatted, contains('Top failing endpoints'));
    });

    test('does not include raw fake secrets', () {
      final controller = DebugKitController();
      controller.init(enabled: true);
      controller.info('token is: abc123secret');
      final logs = controller.store.logs.toList();
      final formatted = DebugLogExportFormatter.formatLogs(
        logs,
        networkSummary: DebugNetworkSummaryBuilder.build(const []),
      );

      expect(formatted, isNot(contains('abc123secret')));
      expect(formatted, contains('ab********et'));
    });
  });

  group('DebugKitController network summary', () {
    test('disabled mode returns an empty summary', () {
      final controller = DebugKitController();
      controller.init(enabled: false);
      final summary = controller.buildNetworkSummary();
      expect(summary.isEmpty, isTrue);
    });
  });
}
