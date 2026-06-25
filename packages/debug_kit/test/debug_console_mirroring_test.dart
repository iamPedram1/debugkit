import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/core/debug_console_log_formatter.dart';
import 'package:debug_kit/src/core/debug_console_printer.dart';
import 'package:debug_kit/src/core/models/debug_kit_config.dart';
import 'package:flutter_test/flutter_test.dart';

final _ansiPattern = RegExp(r'\x1B\[[0-9;]*m');

String _stripAnsi(String value) => value.replaceAll(_ansiPattern, '');

DebugLogEntry _manualEntry({
  int id = 1,
  DebugLogLevel level = DebugLogLevel.info,
  DebugLogSource source = DebugLogSource.app,
  String message = 'App started',
  DateTime? timestamp,
  String? error,
  Map<String, String>? metadata,
}) {
  return DebugLogEntry(
    id: id,
    level: level,
    source: source,
    message: message,
    timestamp: timestamp ?? DateTime(2026, 6, 23, 12, 34, 56),
    error: error,
    metadata: metadata,
  );
}

DebugLogEntry _networkEntry({
  int id = 1,
  DebugLogLevel level = DebugLogLevel.info,
  String phase = 'completed',
  int status = 200,
  int durationMs = 184,
  String method = 'GET',
  String path = '/posts',
  String? requestId = 'req_12',
  String? traceId = 'trace_abc',
  String? traceName = 'feed_flow',
  String? error,
  DateTime? timestamp,
}) {
  return DebugLogEntry(
    id: id,
    level: level,
    source: DebugLogSource.dio,
    message: '$method $path',
    timestamp: timestamp ?? DateTime(2026, 6, 23, 12, 34, 57),
    error: error,
    requestId: requestId,
    traceId: traceId,
    traceName: traceName,
    metadata: {
      'kind': 'networkTransaction',
      'method': method,
      'path': path,
      'phase': phase,
      'status': '$status',
      'duration_ms': '$durationMs',
      'durationMs': '$durationMs',
      if (requestId != null) 'requestId': requestId,
      if (traceId != null) 'traceId': traceId,
      if (traceName != null) 'traceName': traceName,
      'sanitizedUrl': 'https://example.com$path',
      'url': 'https://example.com$path',
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DebugConsoleLogFormatter formatter() => DebugConsoleLogFormatter();
  String logPlain(DebugLogEntry entry, DebugConsolePrintFormat format) =>
      formatter().formatLogEntry(
        entry,
        format: format,
        colorizeConsoleOutput: false,
      );
  String logColored(DebugLogEntry entry, DebugConsolePrintFormat format) =>
      formatter().formatLogEntry(
        entry,
        format: format,
        colorizeConsoleOutput: true,
      );
  String tracePlain({
    required DebugConsolePrintFormat format,
    required String event,
    required String traceName,
    String? traceId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? error,
    Map<String, String>? metadata,
  }) =>
      formatter().formatTraceLifecycle(
        format: format,
        event: event,
        traceName: traceName,
        traceId: traceId,
        startedAt: startedAt,
        endedAt: endedAt,
        error: error,
        metadata: metadata,
        colorizeConsoleOutput: false,
      );
  group('DebugKitConfig', () {
    test('defaults enable console mirroring, color, and dev format', () {
      const config = DebugKitConfig(enabled: true);

      expect(config.printToConsole, isTrue);
      expect(config.printManualLogs, isTrue);
      expect(config.printNetworkLogs, isTrue);
      expect(config.printRouterLogs, isTrue);
      expect(config.printRiverpodLogs, isTrue);
      expect(config.printTraceLogs, isTrue);
      expect(config.printErrorLogs, isTrue);
      expect(config.consolePrintFormat, DebugConsolePrintFormat.dev);
      expect(config.colorizeConsoleOutput, isTrue);
    });
  });

  group('DebugConsoleLogFormatter', () {
    test('formats tiny manual logs', () {
      final output = logPlain(
        _manualEntry(),
        DebugConsolePrintFormat.tiny,
      );

      expect(output, 'INFO · App started');
      expect(output, isNot(contains('DebugKit')));
      expect(output, isNot(contains('12:34:56')));
    });

    test('formats short manual logs', () {
      final output = logPlain(
        _manualEntry(),
        DebugConsolePrintFormat.short,
      );

      expect(output, '12:34:56 · INFO · app · App started');
      expect(output, isNot(contains('DebugKit')));
    });

    test('formats dev manual logs', () {
      final output = logPlain(
        _manualEntry(),
        DebugConsolePrintFormat.dev,
      );

      expect(output, 'ℹ app · App started');
      expect(output, isNot(contains('DebugKit')));
      expect(output, isNot(contains('12:34:56')));
    });

    test('formats detailed manual logs', () {
      final output = logPlain(
        _manualEntry(
          error: 'DioException receive timeout',
          metadata: {'screen': 'home'},
        ),
        DebugConsolePrintFormat.detailed,
      );

      expect(
          output, contains('[DebugKit][2026-06-23T12:34:56.000][INFO][APP]'));
      expect(output, contains('message: App started'));
      expect(output, contains('error: DioException receive timeout'));
      expect(output, contains('screen: home'));
      expect(output, isNot(contains('[APP][APP]')));
    });

    test('formats tiny network logs', () {
      final output = logPlain(
        _networkEntry(),
        DebugConsolePrintFormat.tiny,
      );

      expect(output, 'GET · /posts · 200 · 184ms');
      expect(output, isNot(contains('NET')));
    });

    test('formats tiny network failure logs with status codes', () {
      final output = logPlain(
        _networkEntry(
          level: DebugLogLevel.error,
          phase: 'failed',
          status: 403,
          durationMs: 1179,
          error: 'forbidden',
        ),
        DebugConsolePrintFormat.tiny,
      );

      expect(output, 'GET · /posts · 403 · 1179ms · forbidden');
    });

    test('formats short network logs', () {
      final output = logPlain(
        _networkEntry(),
        DebugConsolePrintFormat.short,
      );

      expect(output, '12:34:57 · NET · GET · /posts · 200 · 184ms');
    });

    test('formats dev network success logs', () {
      final output = logPlain(
        _networkEntry(),
        DebugConsolePrintFormat.dev,
      );

      expect(output, '✓ GET · /posts · 200 · 184ms');
    });

    test('formats dev network redirect and slow logs', () {
      final redirect = logPlain(
        _networkEntry(status: 302),
        DebugConsolePrintFormat.dev,
      );
      final slow = logPlain(
        _networkEntry(
          path: '/layer/list',
          durationMs: 3568,
        ),
        DebugConsolePrintFormat.dev,
      );

      expect(redirect, '↪ GET · /posts · 302 · 184ms');
      expect(slow, '! GET · /layer/list · 200 · 3568ms · slow');
    });

    test('formats dev network failure logs', () {
      final output = logPlain(
        _networkEntry(
          level: DebugLogLevel.error,
          phase: 'failed',
          status: 403,
          durationMs: 315,
          error: 'connectivity',
        ),
        DebugConsolePrintFormat.dev,
      );

      expect(output, '✕ GET · /posts · 403 · 315ms · connectivity');
    });

    test('formats short network failure logs without error noise', () {
      final output = logPlain(
        _networkEntry(
          level: DebugLogLevel.error,
          phase: 'failed',
          status: 403,
          durationMs: 315,
          error: 'receive timeout',
        ),
        DebugConsolePrintFormat.short,
      );

      expect(output, '12:34:57 · NET · GET · /posts · 403 · 315ms');
      expect(output, isNot(contains('receive timeout')));
    });

    test('formats network detailed reports', () {
      final output = logPlain(
        _networkEntry(),
        DebugConsolePrintFormat.detailed,
      );

      expect(output,
          contains('[DebugKit][2026-06-23T12:34:57.000][NETWORK][DIO]'));
      expect(output, contains('method: GET'));
      expect(output, contains('path: /posts'));
      expect(output, contains('status: 200'));
      expect(output, contains('duration: 184ms'));
      expect(output, contains('phase: completed'));
      expect(output, contains('requestId: req_12'));
    });

    test('formats router logs', () {
      final entry = _manualEntry(
        source: DebugLogSource.router,
        message: 'push: /home',
        metadata: {
          'action': 'push',
          'route_path': '/settings',
          'previous_route_path': '/home',
        },
      );

      expect(
        logPlain(entry, DebugConsolePrintFormat.tiny),
        'ROUTE · /home → /settings',
      );
      expect(
        logPlain(entry, DebugConsolePrintFormat.short),
        '12:34:56 · ROUTE · /home → /settings',
      );
      expect(
        logPlain(entry, DebugConsolePrintFormat.dev),
        '↪ /home → /settings',
      );
    });

    test('formats riverpod logs', () {
      final entry = _manualEntry(
        source: DebugLogSource.riverpod,
        level: DebugLogLevel.debug,
        message: 'Riverpod provider updated: authProvider',
        metadata: {
          'provider_name': 'authProvider',
          'event_type': 'provider_update',
        },
      );

      expect(
        logPlain(entry, DebugConsolePrintFormat.tiny),
        'STATE · authProvider · authProvider updated',
      );
      expect(
        logPlain(entry, DebugConsolePrintFormat.short),
        '12:34:56 · STATE · authProvider · authProvider updated',
      );
      expect(
        logPlain(entry, DebugConsolePrintFormat.dev),
        '◆ authProvider · authProvider updated',
      );
    });

    test('formats trace lifecycle events', () {
      expect(
        tracePlain(
          format: DebugConsolePrintFormat.tiny,
          event: 'end',
          traceName: 'startup',
          startedAt: DateTime(2026, 6, 23, 10, 14, 9),
          endedAt: DateTime(2026, 6, 23, 10, 14, 9, 674),
        ),
        'TRACE · startup · completed · 674ms',
      );
      expect(
        tracePlain(
          format: DebugConsolePrintFormat.short,
          event: 'end',
          traceName: 'startup',
          startedAt: DateTime(2026, 6, 23, 10, 14, 9),
          endedAt: DateTime(2026, 6, 23, 10, 14, 9, 674),
        ),
        '10:14:09 · TRACE · startup · completed · 674ms',
      );
      expect(
        tracePlain(
          format: DebugConsolePrintFormat.dev,
          event: 'end',
          traceName: 'startup',
          startedAt: DateTime(2026, 6, 23, 10, 14, 9),
          endedAt: DateTime(2026, 6, 23, 10, 14, 9, 674),
        ),
        '⏱ · startup · completed · 674ms',
      );
    });

    test('formats detailed trace lifecycle events', () {
      final output = tracePlain(
        format: DebugConsolePrintFormat.detailed,
        event: 'start',
        traceName: 'checkout_flow',
        traceId: 'trace_1',
        startedAt: DateTime(2026, 6, 23, 12, 34, 56),
        metadata: {'screen': 'checkout'},
      );

      expect(output, contains('[DebugKit][2026-06-23T12:34:56.000][TRACE]'));
      expect(output, contains('name: checkout_flow'));
      expect(output, contains('event: started'));
      expect(output, contains('traceId: trace_1'));
      expect(output, contains('screen: checkout'));
    });

    test('keeps sanitized tokens out of console output', () {
      const raw = 'Authorization: Bearer my_super_secret_token_123';
      final sanitized = DebugLogSanitizer.sanitizeMessage(raw);
      final output = logPlain(
        _manualEntry(message: sanitized),
        DebugConsolePrintFormat.dev,
      );

      expect(output, isNot(contains('my_super_secret_token_123')));
      expect(output, contains(sanitized));
    });

    test('truncates very long messages', () {
      final longMessage = List.generate(200, (_) => 'x').join();
      final output = logPlain(
        _manualEntry(message: longMessage),
        DebugConsolePrintFormat.dev,
      );

      expect(output, contains('…'));
      expect(output.length, lessThan(longMessage.length));
    });

    test('colorized output can be stripped back to plain text', () {
      final output = logColored(
        _networkEntry(),
        DebugConsolePrintFormat.dev,
      );

      expect(output, contains('\x1B['));
      expect(
        _stripAnsi(output),
        '✓ GET · /posts · 200 · 184ms',
      );
    });

    test('colorized network output includes ANSI colors', () {
      final success = logColored(
        _networkEntry(),
        DebugConsolePrintFormat.dev,
      );
      final failure = logColored(
        _networkEntry(
          level: DebugLogLevel.error,
          phase: 'failed',
          status: 403,
          durationMs: 315,
          error: 'connectivity',
        ),
        DebugConsolePrintFormat.dev,
      );
      final slow = logColored(
        _networkEntry(
          path: '/layer/list',
          durationMs: 3568,
        ),
        DebugConsolePrintFormat.dev,
      );

      expect(success, contains('\x1B[32m'));
      expect(failure, contains('\x1B[33m'));
      expect(slow, contains('\x1B[33m'));
      expect(_stripAnsi(success), '✓ GET · /posts · 200 · 184ms');
      expect(
        _stripAnsi(failure),
        '✕ GET · /posts · 403 · 315ms · connectivity',
      );
      expect(
        _stripAnsi(slow),
        '! GET · /layer/list · 200 · 3568ms · slow',
      );
    });
  });

  group('DebugConsolePrinter', () {
    test('does not print when console mirroring is disabled', () {
      final messages = <String>[];
      final printer = DebugConsolePrinter(
        config: const DebugKitConfig(
          enabled: true,
          printToConsole: false,
        ),
        sink: messages.add,
      );

      printer.printLogEntry(_manualEntry());

      expect(messages, isEmpty);
    });

    test('respects category toggles', () {
      final messages = <String>[];
      final printer = DebugConsolePrinter(
        config: const DebugKitConfig(
          enabled: true,
          colorizeConsoleOutput: false,
          printNetworkLogs: false,
          printRouterLogs: false,
          printRiverpodLogs: false,
          printTraceLogs: false,
          printErrorLogs: false,
        ),
        sink: messages.add,
      );

      printer.printLogEntry(_manualEntry());
      printer.printLogEntry(_networkEntry());
      printer.printLogEntry(_manualEntry(source: DebugLogSource.router));
      printer.printLogEntry(_manualEntry(source: DebugLogSource.riverpod));
      printer.printTraceLifecycle(
        event: 'start',
        traceName: 'checkout_flow',
      );

      expect(messages, hasLength(1));
      expect(messages.single, 'ℹ app · App started');
    });

    test('prints error logs when enabled', () {
      final messages = <String>[];
      final printer = DebugConsolePrinter(
        config: const DebugKitConfig(
          enabled: true,
          colorizeConsoleOutput: false,
          printManualLogs: false,
          printNetworkLogs: false,
          printRouterLogs: false,
          printRiverpodLogs: false,
          printTraceLogs: false,
          printErrorLogs: true,
        ),
        sink: messages.add,
      );

      printer.printLogEntry(
        _manualEntry(
          level: DebugLogLevel.error,
          message: 'Failed to load profile',
          error: 'DioException receive timeout',
        ),
      );

      expect(messages, hasLength(1));
      expect(messages.single,
          '✕ app · Failed to load profile · DioException receive timeout');
    });

    test('prints plain output when colorization is disabled', () {
      final messages = <String>[];
      final printer = DebugConsolePrinter(
        config: const DebugKitConfig(
          enabled: true,
          colorizeConsoleOutput: false,
        ),
        sink: messages.add,
      );

      printer.printLogEntry(_networkEntry());

      expect(messages.single, '✓ GET · /posts · 200 · 184ms');
      expect(messages.single, isNot(contains('\x1B[')));
    });

    test('prints colored output when colorization is enabled', () {
      final messages = <String>[];
      final printer = DebugConsolePrinter(
        config: const DebugKitConfig(
          enabled: true,
          colorizeConsoleOutput: true,
        ),
        sink: messages.add,
      );

      printer.printLogEntry(_networkEntry());

      expect(messages.single, contains('\x1B['));
      expect(_stripAnsi(messages.single), '✓ GET · /posts · 200 · 184ms');
    });

    test('prints sanitized output only', () {
      final messages = <String>[];
      final printer = DebugConsolePrinter(
        config: const DebugKitConfig(
          enabled: true,
          colorizeConsoleOutput: false,
        ),
        sink: messages.add,
      );

      final sanitized = DebugLogSanitizer.sanitizeMessage(
        'token=my_super_secret_token_123',
      );
      printer.printLogEntry(_manualEntry(message: sanitized));

      expect(messages.single, contains(sanitized));
      expect(messages.single, isNot(contains('my_super_secret_token_123')));
      expect(messages.single, isNot(contains('\x1B[')));
    });
  });
}
