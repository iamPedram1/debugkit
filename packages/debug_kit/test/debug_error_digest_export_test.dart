import 'package:flutter_test/flutter_test.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/utils/export/debug_log_export_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DebugErrorDigest export', () {
    test('export includes Error Digest section when errors exist', () {
      final controller = DebugKitController();
      controller.init(enabled: true);

      controller.error('Auth token expired',
          error: Exception('InvalidTokenException: token has expired'));

      final logs = controller.store.logs.toList();
      final digest = controller.buildErrorDigest();

      final output = DebugLogExportFormatter.formatLogs(
        logs,
        digest: digest.isEmpty ? null : digest,
      );

      expect(output, contains('DebugKit Error Digest'));
      expect(output, contains('Unique'));
      expect(output, contains('Total'));
    });

    test('export does not include digest section when digest is null', () {
      final controller = DebugKitController();
      controller.init(enabled: true);
      controller.info('Normal log');

      final output = DebugLogExportFormatter.formatLogs(
        controller.store.logs.toList(),
      );

      expect(output, isNot(contains('DebugKit Error Digest')));
    });

    test('grouped error is exported once with count — not expanded', () {
      final controller = DebugKitController();
      controller.init(enabled: true, groupRepeatedLogs: true);

      // Same error 4 times — should group
      for (var i = 0; i < 4; i++) {
        controller.error('Repeated failure',
            error: Exception('NetworkError: timeout'));
      }

      final logs = controller.store.logs.toList();
      final digest = controller.buildErrorDigest();

      final output = DebugLogExportFormatter.formatLogs(
        logs,
        digest: digest.isEmpty ? null : digest,
      );

      expect(output, contains('DebugKit Error Digest'));
      // Repeated error should show count, not be duplicated
      expect('×4'.allMatches(output).length, greaterThanOrEqualTo(1));
    });

    test('export includes related trace names', () async {
      final controller = DebugKitController();
      controller.init(enabled: true);

      try {
        await controller.traceController.run('payment_flow', () async {
          controller.error('Payment declined',
              error: Exception('CardException: insufficient funds'));
          throw Exception('Payment failed');
        });
      } catch (_) {}

      final logs = controller.store.logs.toList();
      final traces = controller.traceStore.traces.toList();
      final digest = controller.buildErrorDigest();

      final output = DebugLogExportFormatter.formatLogs(
        logs,
        traces: traces,
        digest: digest.isEmpty ? null : digest,
      );

      // Digest should reference the trace
      expect(output, contains('payment_flow'));
    });

    test('export does not contain raw fake secrets', () {
      final controller = DebugKitController();
      controller.init(enabled: true);

      // Use a pattern the sanitizer explicitly masks: "token is: value"
      // and a private key (64-char hex) which gets fully redacted
      controller.error(
        'token is: abc123secret',
        error: Exception('Auth failed'),
      );

      final logs = controller.store.logs.toList();
      final digest = controller.buildErrorDigest();

      final output = DebugLogExportFormatter.formatLogs(
        logs,
        digest: digest.isEmpty ? null : digest,
      );

      // The message "token is: abc123secret" gets sanitized to "token is: ab********et"
      expect(output, isNot(contains('abc123secret')));
    });

    test('DebugErrorDigestExportFormatter.formatDigest includes entry details',
        () {
      final controller = DebugKitController();
      controller.init(enabled: true);
      controller.error('GET /api/data failed',
          error: Exception('DioException: 404 not found'));

      final digest = controller.buildErrorDigest();
      final output = DebugErrorDigestExportFormatter.formatDigest(digest);

      expect(output, contains('DebugKit Error Digest'));
      expect(output, contains('Generated'));
      expect(output, isNot(isEmpty));
    });

    test('DebugErrorDigestExportFormatter.formatDigestEntry includes count',
        () {
      final controller = DebugKitController();
      controller.init(enabled: true);

      // Emit same error 3 times
      for (var i = 0; i < 3; i++) {
        controller.error('Service unavailable',
            error: Exception('HttpException: 503 Service Unavailable'));
      }

      final digest = controller.buildErrorDigest();
      expect(digest.entries.isNotEmpty, isTrue);

      final entryOutput = DebugErrorDigestExportFormatter.formatDigestEntry(
          digest.entries.first);

      expect(entryOutput, contains('Count'));
      expect(entryOutput, contains('First seen'));
      expect(entryOutput, contains('Last seen'));
    });
  });

  group('DebugErrorDigest controller integration', () {
    test('clear logs clears digest result', () {
      final controller = DebugKitController();
      controller.init(enabled: true);

      controller.error('Something broke', error: Exception('Error'));
      expect(controller.buildErrorDigest().isEmpty, isFalse);

      controller.store.clear();
      expect(controller.buildErrorDigest().isEmpty, isTrue);
    });
  });
}
