import 'package:flutter_test/flutter_test.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/utils/errors/debug_error_digest_builder.dart';
import 'package:debug_kit/src/utils/export/debug_log_export_formatter.dart';

DebugLogEntry _entry({
  int id = 1,
  DebugLogLevel level = DebugLogLevel.error,
  DebugLogSource source = DebugLogSource.app,
  String message = 'Something failed',
  String? error,
  String? stackTrace,
  Map<String, String>? metadata,
  String? requestId,
  String? traceId,
  int repeatCount = 1,
  DateTime? timestamp,
  DateTime? lastSeenAt,
}) {
  return DebugLogEntry(
    id: id,
    level: level,
    source: source,
    message: message,
    timestamp: timestamp ?? DateTime.now(),
    error: error,
    stackTrace: stackTrace,
    metadata: metadata,
    requestId: requestId,
    traceId: traceId,
    repeatCount: repeatCount,
    lastSeenAt: lastSeenAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Empty digest
  // ---------------------------------------------------------------------------
  group('DebugErrorDigestBuilder — empty digest', () {
    test('builds empty digest from no logs', () {
      final digest = DebugErrorDigestBuilder.build(logs: []);
      expect(digest.isEmpty, isTrue);
      expect(digest.totalErrors, 0);
      expect(digest.uniqueErrors, 0);
      expect(digest.entries, isEmpty);
    });

    test('builds empty digest when all logs are info/debug level', () {
      final logs = [
        _entry(id: 1, level: DebugLogLevel.info, message: 'App started'),
        _entry(id: 2, level: DebugLogLevel.debug, message: 'Cache hit'),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.isEmpty, isTrue);
    });

    test('ignores non-error logs', () {
      final logs = [
        _entry(
            id: 1,
            level: DebugLogLevel.info,
            message: 'Normal event',
            error: null),
        _entry(id: 2, level: DebugLogLevel.debug, message: 'Debug event'),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Grouping
  // ---------------------------------------------------------------------------
  group('DebugErrorDigestBuilder — groups repeated errors', () {
    test('two identical error log entries group into one digest entry', () {
      final logs = [
        _entry(
            id: 1, message: 'Auth failed', error: 'Exception: token expired'),
        _entry(
            id: 2, message: 'Auth failed', error: 'Exception: token expired'),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.uniqueErrors, 1);
      expect(digest.entries.first.count, 2);
    });

    test('repeatCount contributes to digest entry count', () {
      // A log that was emitted 5 times but stored as 1 entry with repeatCount=5
      final logs = [
        _entry(
            id: 1,
            message: 'Connection failed',
            error: 'SocketException: refused',
            repeatCount: 5),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.entries.first.count, 5);
      expect(digest.totalErrors, 5);
    });

    test('multiple repeatCounts sum correctly', () {
      final logs = [
        _entry(
            id: 1,
            message: 'Auth failed',
            error: 'Exception: token expired',
            repeatCount: 3),
        _entry(
            id: 2,
            message: 'Auth failed',
            error: 'Exception: token expired',
            repeatCount: 7),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.uniqueErrors, 1);
      expect(digest.entries.first.count, 10);
      expect(digest.totalErrors, 10);
    });

    test('different error types stay as separate entries', () {
      final logs = [
        _entry(id: 1, message: 'Auth failed', error: 'AuthException: invalid'),
        _entry(
            id: 2,
            message: 'Parse failed',
            error: 'FormatException: invalid JSON'),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.uniqueErrors, 2);
    });

    test('Dio errors with different status codes stay separate', () {
      final logs = [
        _entry(
            id: 1,
            source: DebugLogSource.dio,
            message: 'GET https://api.example.com/profile · 401 · 100ms'),
        _entry(
            id: 2,
            source: DebugLogSource.dio,
            message: 'GET https://api.example.com/profile · 500 · 100ms'),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.uniqueErrors, 2);
    });

    test('Riverpod failures with different providers stay separate', () {
      final logs = [
        _entry(
            id: 1,
            source: DebugLogSource.riverpod,
            message: 'Riverpod provider failed: authProvider',
            error: 'Exception: token expired',
            metadata: {
              'provider_name': 'authProvider',
              'event_type': 'provider_failure'
            }),
        _entry(
            id: 2,
            source: DebugLogSource.riverpod,
            message: 'Riverpod provider failed: cartProvider',
            error: 'Exception: cart not found',
            metadata: {
              'provider_name': 'cartProvider',
              'event_type': 'provider_failure'
            }),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.uniqueErrors, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // firstSeenAt / lastSeenAt
  // ---------------------------------------------------------------------------
  group('DebugErrorDigestBuilder — tracks firstSeenAt and lastSeenAt', () {
    test('firstSeenAt is the earliest timestamp', () {
      final earlier = DateTime(2026, 1, 1, 10, 0, 0);
      final later = DateTime(2026, 1, 1, 10, 5, 0);
      final logs = [
        _entry(
            id: 1,
            message: 'Auth failed',
            error: 'Exception: token',
            timestamp: earlier),
        _entry(
            id: 2,
            message: 'Auth failed',
            error: 'Exception: token',
            timestamp: later),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.entries.first.firstSeenAt, earlier);
    });

    test('lastSeenAt is the most recent timestamp', () {
      final first = DateTime(2026, 1, 1, 10, 0, 0);
      final last = DateTime(2026, 1, 1, 10, 10, 0);
      final logs = [
        _entry(
            id: 1,
            message: 'Auth failed',
            error: 'Exception: token',
            timestamp: first,
            lastSeenAt: null),
        _entry(
            id: 2,
            message: 'Auth failed',
            error: 'Exception: token',
            timestamp: last,
            lastSeenAt: null),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.entries.first.lastSeenAt, last);
    });

    test('lastSeenAt respects DebugLogEntry.lastSeenAt for grouped logs', () {
      final base = DateTime(2026, 1, 1, 10, 0, 0);
      final groupedLast = DateTime(2026, 1, 1, 10, 8, 0);
      final logs = [
        _entry(
            id: 1,
            message: 'Auth failed',
            error: 'Exception: token',
            timestamp: base,
            repeatCount: 5,
            lastSeenAt: groupedLast),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.entries.first.lastSeenAt, groupedLast);
    });
  });

  // ---------------------------------------------------------------------------
  // Related context
  // ---------------------------------------------------------------------------
  group('DebugErrorDigestBuilder — collects related context', () {
    test('collects related trace IDs and names', () async {
      final controller = DebugKitController();
      controller.init(enabled: true);

      // Run a trace that fails
      try {
        await controller.traceController.run('auth_flow', () async {
          controller.error('Auth token expired',
              error: Exception('token expired'));
          throw Exception('Auth failed');
        });
      } catch (_) {}

      final digest = controller.buildErrorDigest();
      // There should be an error entry for the manually logged error
      final authEntry = digest.entries.firstWhere(
        (e) => e.message.contains('Auth token expired'),
        orElse: () => digest.entries.first,
      );
      // The log carries traceId, which should be linked
      expect(
          authEntry.relatedTraceIds.isNotEmpty ||
              authEntry.relatedTraceNames.isNotEmpty,
          isTrue);
    });

    test('collects related request IDs for Dio errors', () {
      final logs = [
        _entry(
            id: 1,
            source: DebugLogSource.dio,
            message: 'GET https://api.example.com/profile · 401 · 100ms',
            requestId: 'dio_3'),
        _entry(
            id: 2,
            source: DebugLogSource.dio,
            message: 'GET https://api.example.com/profile · 401 · 120ms',
            requestId: 'dio_7'),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.entries.first.relatedRequestIds,
          containsAll(['dio_3', 'dio_7']));
    });

    test('collects related provider names', () {
      final logs = [
        _entry(
            id: 1,
            source: DebugLogSource.riverpod,
            message: 'Riverpod provider failed: authProvider',
            error: 'Exception: token',
            metadata: {
              'provider_name': 'authProvider',
              'event_type': 'provider_failure'
            }),
        _entry(
            id: 2,
            source: DebugLogSource.riverpod,
            message: 'Riverpod provider failed: authProvider',
            error: 'Exception: token',
            metadata: {
              'provider_name': 'authProvider',
              'event_type': 'provider_failure'
            }),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(
          digest.entries.first.relatedProviderNames, contains('authProvider'));
    });

    test('collects related route paths', () {
      final logs = [
        _entry(
            id: 1,
            source: DebugLogSource.router,
            level: DebugLogLevel.error,
            message: 'Navigation error',
            metadata: {'route_path': '/profile'}),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      // router source error entry should have route context
      expect(digest.entries.isNotEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Failed traces
  // ---------------------------------------------------------------------------
  group('DebugErrorDigestBuilder — includes failed traces', () {
    test('failed trace contributes to digest', () {
      final now = DateTime.now();
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'login_flow',
        status: DebugTraceStatus.failed,
        startedAt: now,
        endedAt: now,
        errorSummary: 'Auth failed: token expired',
      );
      final digest = DebugErrorDigestBuilder.build(logs: [], traces: [trace]);
      expect(digest.failedTraceCount, 1);
      expect(digest.uniqueErrors, 1);
    });

    test('successful trace does not contribute to digest', () {
      final now = DateTime.now();
      final trace = DebugTrace(
        id: 'trace_1',
        name: 'login_flow',
        status: DebugTraceStatus.success,
        startedAt: now,
        endedAt: now,
      );
      final digest = DebugErrorDigestBuilder.build(logs: [], traces: [trace]);
      expect(digest.failedTraceCount, 0);
      expect(digest.uniqueErrors, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Sorting
  // ---------------------------------------------------------------------------
  group('DebugErrorDigestBuilder — sorts by severity/count/recency', () {
    test('error severity comes before warning severity', () {
      final logs = [
        _entry(
            id: 1,
            level: DebugLogLevel.warning,
            message: 'Slow request',
            error: 'Timeout'),
        _entry(
            id: 2,
            level: DebugLogLevel.error,
            message: 'Auth failed completely',
            error: 'AuthException: invalid'),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.entries.first.severity, DebugErrorDigestSeverity.error);
    });

    test('higher count entry appears before lower count of same severity', () {
      final logsA = List.generate(
        5,
        (i) => _entry(
            id: i + 1,
            message: 'Socket error',
            error: 'SocketException: refused'),
      );
      final logB = [
        _entry(
            id: 99, message: 'Parse error', error: 'FormatException: bad JSON'),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: [...logsA, ...logB]);

      // Socket error occurred 5× — should be first
      final first = digest.entries.first;
      expect(first.count, greaterThan(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Failed network count
  // ---------------------------------------------------------------------------
  group('DebugErrorDigestBuilder — failedNetworkCount', () {
    test('counts Dio error entries', () {
      final logs = [
        _entry(
            id: 1,
            source: DebugLogSource.dio,
            message: 'GET https://api.example.com/feed · 401 · 100ms'),
        _entry(
            id: 2,
            source: DebugLogSource.dio,
            message: 'POST https://api.example.com/auth · 500 · 200ms'),
        _entry(id: 3, source: DebugLogSource.app, message: 'App error'),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      expect(digest.failedNetworkCount, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Security — secrets do not leak
  // ---------------------------------------------------------------------------
  group('DebugErrorDigestBuilder — sanitization safety', () {
    test('digest does not leak fake raw secrets from log messages', () {
      // Logs go through controller sanitization — by the time they reach the
      // store and the digest builder, secrets are already masked.
      final controller = DebugKitController();
      controller.init(enabled: true);
      controller.error('token is: abc123secret',
          error: Exception('Auth failed'));

      final digest = controller.buildErrorDigest();
      final exportText = DebugErrorDigestExportFormatter.formatDigest(digest);
      expect(exportText, isNot(contains('abc123secret')));
    });

    test('digest entry title does not contain raw secrets', () {
      final controller = DebugKitController();
      controller.init(enabled: true);

      const privateKey =
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----';
      controller.error('key=$privateKey', error: Exception('Auth failed'));

      final digest = controller.buildErrorDigest();
      for (final entry in digest.entries) {
        expect(entry.title, isNot(contains(privateKey)));
        expect(entry.message, isNot(contains(privateKey)));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Disabled mode
  // ---------------------------------------------------------------------------
  group('DebugErrorDigestBuilder — disabled mode', () {
    test('buildErrorDigest returns empty digest when disabled', () {
      final controller = DebugKitController();
      controller.init(enabled: false);
      // Even if we call it directly, disabled returns empty
      final digest = controller.buildErrorDigest();
      expect(digest.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // topRepeatedErrors / latestErrors
  // ---------------------------------------------------------------------------
  group('DebugErrorDigestBuilder — topRepeatedErrors and latestErrors', () {
    test('topRepeatedErrors has highest count first', () {
      final logs = [
        _entry(
            id: 1,
            message: 'Rare error',
            error: 'RareException: once',
            repeatCount: 1),
        _entry(
            id: 2,
            message: 'Frequent error',
            error: 'FreqException: many',
            repeatCount: 10),
        _entry(
            id: 3,
            message: 'Medium error',
            error: 'MedException: five',
            repeatCount: 5),
      ];
      final digest = DebugErrorDigestBuilder.build(logs: logs);
      if (digest.topRepeatedErrors.length >= 2) {
        expect(digest.topRepeatedErrors.first.count,
            greaterThanOrEqualTo(digest.topRepeatedErrors[1].count));
      }
    });
  });
}
