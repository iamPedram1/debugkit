import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/core/models/debug_kit_config.dart';
import 'package:debug_kit/src/core/store/debug_log_store.dart';
import 'package:debug_kit/src/utils/export/debug_log_export_formatter.dart';
import 'package:debug_kit/src/utils/export/debug_log_file_exporter.dart';
import 'package:debug_kit/src/utils/filtering/debug_log_filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DebugLogStore', () {
    test('appends logs', () {
      final store = DebugLogStore(maxLogs: 10, groupRepeated: false);
      store.addLog(DebugLogEntry(
        id: 1,
        level: DebugLogLevel.info,
        source: DebugLogSource.app,
        message: 'Test log',
        timestamp: DateTime.now(),
      ));
      expect(store.logs.length, 1);
      expect(store.logs.first.message, 'Test log');
    });

    test('evicts oldest logs after maxLogs', () {
      final store = DebugLogStore(maxLogs: 3, groupRepeated: false);
      for (var i = 1; i <= 5; i++) {
        store.addLog(DebugLogEntry(
          id: i,
          level: DebugLogLevel.info,
          source: DebugLogSource.app,
          message: 'Log $i',
          timestamp: DateTime.now(),
        ));
      }
      expect(store.logs.length, 3);
      expect(store.logs.first.message, 'Log 3');
      expect(store.logs.last.message, 'Log 5');
    });

    test('clear removes all logs', () {
      final store = DebugLogStore(maxLogs: 10, groupRepeated: false);
      store.addLog(DebugLogEntry(
        id: 1,
        level: DebugLogLevel.info,
        source: DebugLogSource.app,
        message: 'Test log',
        timestamp: DateTime.now(),
      ));
      store.clear();
      expect(store.logs.length, 0);
    });
  });

  group('DebugKitController', () {
    test('disabled DebugKit does not store logs', () {
      final controller = DebugKitController();
      controller.init(enabled: false);
      controller.info('Should not be stored');
      expect(controller.store.logs.length, 0);
    });

    test('logging stores sanitized entries', () {
      final controller = DebugKitController();
      controller.init(enabled: true, groupRepeatedLogs: false);
      controller.info('App started with key='
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----');

      expect(controller.store.logs.length, 1);
      final entry = controller.store.logs.first;
      expect(entry.message, contains('[REDACTED PRIVATE KEY]'));
      expect(entry.level, DebugLogLevel.info);
      expect(entry.source, DebugLogSource.app);
    });
  });

  group('DebugKit facade', () {
    test('disableDefaultOverlayButton defaults to false', () {
      const config = DebugKitConfig(enabled: true);
      expect(config.disableDefaultOverlayButton, isFalse);
    });

    test('isEnabled reflects init state', () {
      DebugKit.init(enabled: true);
      expect(DebugKit.isEnabled, isTrue);
      DebugKit.init(enabled: false);
      expect(DebugKit.isEnabled, isFalse);
      // Reset for subsequent tests
      DebugKit.init(enabled: true);
    });

    test('clearLogs removes all logs', () {
      DebugKit.init(enabled: true);
      DebugKit.log.info('Test log');
      expect(DebugKit.controller.store.logs.length, greaterThan(0));
      DebugKit.clearLogs();
      expect(DebugKit.controller.store.logs.isEmpty, isTrue);
    });

    test('sanitizer config is honored by controller logging', () {
      DebugKit.init(
        enabled: true,
        printToConsole: false,
        sanitizer: const DebugKitSanitizerConfig(
          dangerouslyDisableSanitizer: true,
        ),
      );

      const raw =
          'token=secret123 password=my_password -----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----';
      DebugKit.log.info(raw);

      expect(DebugKit.controller.store.logs.single.message, raw);
    });

    test('open and close do not throw when disabled', () {
      final navigatorKey = GlobalKey<NavigatorState>();
      DebugKit.init(
        enabled: false,
        navigatorKey: navigatorKey,
      );

      expect(() => DebugKit.open(), returnsNormally);
      expect(() => DebugKit.close(), returnsNormally);
    });

    test('open and close do not throw before overlay mount', () {
      final navigatorKey = GlobalKey<NavigatorState>();
      DebugKit.init(
        enabled: true,
        navigatorKey: navigatorKey,
      );

      expect(() => DebugKit.open(), returnsNormally);
      expect(() => DebugKit.close(), returnsNormally);
    });
  });

  group('DebugLogSanitizer', () {
    test('maskSensitiveValue behavior', () {
      expect(DebugLogSanitizer.maskValue('abc'), '***');
      expect(DebugLogSanitizer.maskValue('abcd'), 'a**d');
      expect(DebugLogSanitizer.maskValue('testing'), 'te***ng');
      expect(DebugLogSanitizer.maskValue('testingmylongpassword'),
          'tes***************ord');
      expect(DebugLogSanitizer.maskValue('my_super_secret_password123'),
          'my_*********************123');
    });

    test('masks bearer tokens with smart masking', () {
      final sanitized = DebugLogSanitizer.sanitizeMessage(
          'Bearer eyJhYmNkZWZ0aGlzaXNhdmVyeWxvbmf0b2tlbiJ9');
      // Original length: 40. start 3, end 3. middle 34.
      expect(sanitized, contains('eyJ**********************************iJ9'));
    });

    test('masks natural language secrets', () {
      expect(
          DebugLogSanitizer.sanitizeMessage(
              'User password is: my_super_secret_password123'),
          'User password is: my_*********************123');
      expect(
          DebugLogSanitizer.sanitizeMessage(
              'password: my_super_secret_password123'),
          'password: my_*********************123');
      expect(
          DebugLogSanitizer.sanitizeMessage(
              'password=my_super_secret_password123'),
          'password=my_*********************123');
      // abc123secret is 12 chars. Rule: keep 2. middle 8.
      expect(DebugLogSanitizer.sanitizeMessage('token is: abc123secret'),
          'token is: ab********et');
      expect(DebugLogSanitizer.sanitizeMessage('api_key is abc123secret'),
          'api_key is ab********et');
      expect(DebugLogSanitizer.sanitizeMessage('secret = abc123secret'),
          'secret = ab********et');
    });

    test('does not mask harmless mentions', () {
      expect(DebugLogSanitizer.sanitizeMessage('Password screen opened'),
          'Password screen opened');
      expect(
          DebugLogSanitizer.sanitizeMessage(
              'User changed password successfully'),
          'User changed password successfully');
      expect(DebugLogSanitizer.sanitizeMessage('Password validation failed'),
          'Password validation failed');
    });

    test('masks cookies', () {
      final headers = {'cookie': 'session=1234567890abcdef; other=value'};
      final sanitized = DebugLogSanitizer.sanitizeHeaders(headers);
      // Length 37. start 3, end 3. middle 31.
      expect(sanitized['cookie'], 'ses*******************************lue');
    });

    test('masks metadata', () {
      final metadata = {
        'api_key': 'abc123secret',
        'safe_key': 'safe_value',
      };
      final sanitized = DebugLogSanitizer.sanitizeMetadata(metadata);
      // abc123secret is 12 chars. Rule: keep 2. middle 8.
      expect(sanitized!['api_key'], 'ab********et');
      expect(sanitized['safe_key'], 'safe_value');
    });

    test('fully redacts PEM private keys', () {
      const key =
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----';
      final sanitized = DebugLogSanitizer.sanitizeMessage('My key is $key');
      expect(sanitized, contains('[REDACTED PRIVATE KEY]'));
      expect(sanitized, isNot(contains('abc123')));
    });

    test('fully redacts labeled mnemonics', () {
      const mnemonic =
          'apple banana cherry dog elephant fish goat house ice jump kite lemon';
      final sanitized1 =
          DebugLogSanitizer.sanitizeMessage('mnemonic: $mnemonic');
      final sanitized2 =
          DebugLogSanitizer.sanitizeMessage('seed phrase is: $mnemonic');
      final sanitized3 =
          DebugLogSanitizer.sanitizeMessage('recovery phrase=$mnemonic');
      expect(sanitized1, 'mnemonic: [REDACTED MNEMONIC]');
      expect(sanitized2, 'seed phrase is: [REDACTED MNEMONIC]');
      expect(sanitized3, 'recovery phrase=[REDACTED MNEMONIC]');
    });

    test('does not over-mask normal english sentences', () {
      const normalSentence =
          'the quick brown fox jumps over the lazy dog and the dog barks loudly';
      final sanitized =
          DebugLogSanitizer.sanitizeMessage('User said: $normalSentence');
      expect(sanitized, 'User said: $normalSentence');
    });

    test('trims stack traces', () {
      final longStackTrace = List.generate(50, (i) => 'line $i').join('\n');
      final trimmed =
          DebugLogSanitizer.trimStackTrace(longStackTrace, maxLines: 5);
      expect(trimmed, contains('line 4'));
      expect(trimmed, isNot(contains('line 5')));
      expect(trimmed, contains('45 lines trimmed'));
    });

    test('does not redact canonical hash values by default', () {
      const log =
          '[CanonicalDiff] client hashes stroke=abc123 point=def456 layer=ghi789 zone=jkl012 manifest=mno345 image=pqr678';

      expect(DebugLogSanitizer.sanitizeMessage(log), log);
    });

    test('does not redact sha256-like values by default', () {
      const log =
          'sha256=9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';

      expect(DebugLogSanitizer.sanitizeMessage(log), log);
    });

    test('does not redact UUID-like values by default', () {
      const log = 'request_id=123e4567-e89b-12d3-a456-426614174000';

      expect(DebugLogSanitizer.sanitizeMessage(log), log);
    });

    test('Joyn-style canonical diff log remains readable', () {
      const log =
          '[CanonicalDiff] client hashes stroke=abc123 point=def456 layer=ghi789 zone=jkl012 manifest=mno345 image=pqr678';

      expect(DebugLogSanitizer.sanitizeMessage(log), log);
    });

    test('dangerouslyDisableSanitizer returns raw values unchanged', () {
      const pem =
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----';
      const raw =
          'token=secret123 password=my_password Authorization: Bearer raw-token Cookie: session=abc123 $pem';

      final sanitized = DebugLogSanitizer.sanitizeMessage(
        raw,
        config: const DebugKitSanitizerConfig(
          dangerouslyDisableSanitizer: true,
          redactTokens: false,
          redactAuthorizationHeaders: false,
          redactCookies: false,
          redactApiKeys: false,
          redactPasswords: false,
          redactPrivateKeys: false,
          redactMnemonics: false,
        ),
      );

      expect(sanitized, raw);
    });

    test('private key redaction can be disabled', () {
      const pem =
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----';
      final sanitized = DebugLogSanitizer.sanitizeMessage(
        'key=$pem',
        config: const DebugKitSanitizerConfig(redactPrivateKeys: false),
      );

      expect(sanitized, contains('BEGIN PRIVATE KEY'));
      expect(sanitized, isNot(contains('[REDACTED PRIVATE KEY]')));
    });

    test('redactTokens false leaves token values visible', () {
      const pem =
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----';
      final sanitized = DebugLogSanitizer.sanitizeMessage(
        'token=secret123 password=my_password $pem',
        config: const DebugKitSanitizerConfig(redactTokens: false),
      );

      expect(sanitized, contains('token=secret123'));
      expect(sanitized, isNot(contains('my_password')));
      expect(sanitized, contains('[REDACTED PRIVATE KEY]'));
    });

    test('redactPasswords false leaves password values visible', () {
      const pem =
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----';
      final sanitized = DebugLogSanitizer.sanitizeMessage(
        'password=my_password token=secret123 $pem',
        config: const DebugKitSanitizerConfig(redactPasswords: false),
      );

      expect(sanitized, contains('password=my_password'));
      expect(sanitized, isNot(contains('secret123')));
      expect(sanitized, contains('[REDACTED PRIVATE KEY]'));
    });

    test('redactApiKeys false leaves api keys visible', () {
      const pem =
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----';
      final sanitized = DebugLogSanitizer.sanitizeMessage(
        'api_key=secret123 password=my_password $pem',
        config: const DebugKitSanitizerConfig(redactApiKeys: false),
      );

      expect(sanitized, contains('api_key=secret123'));
      expect(sanitized, isNot(contains('my_password')));
      expect(sanitized, contains('[REDACTED PRIVATE KEY]'));
    });

    test(
        'redactAuthorizationHeaders false leaves authorization headers visible',
        () {
      const pem =
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----';
      final sanitized = DebugLogSanitizer.sanitizeMessage(
        'Authorization: Bearer raw-token\npassword=my_password\n$pem',
        config:
            const DebugKitSanitizerConfig(redactAuthorizationHeaders: false),
      );

      expect(sanitized, contains('Authorization: Bearer raw-token'));
      expect(sanitized, isNot(contains('my_password')));
      expect(sanitized, contains('[REDACTED PRIVATE KEY]'));
    });

    test('redactCookies false leaves cookies visible', () {
      const pem =
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----';
      final sanitized = DebugLogSanitizer.sanitizeMessage(
        'Cookie: session=abc123\npassword=my_password\n$pem',
        config: const DebugKitSanitizerConfig(redactCookies: false),
      );

      expect(sanitized, contains('Cookie: session=abc123'));
      expect(sanitized, isNot(contains('my_password')));
      expect(sanitized, contains('[REDACTED PRIVATE KEY]'));
    });

    test('redactMnemonics false leaves mnemonics visible', () {
      const pem =
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----';
      const mnemonic =
          'apple banana cherry dog elephant fish goat house ice jump kite lemon';
      final sanitized = DebugLogSanitizer.sanitizeMessage(
        'mnemonic: $mnemonic token=secret123 $pem',
        config: const DebugKitSanitizerConfig(redactMnemonics: false),
      );

      expect(sanitized, contains('mnemonic: $mnemonic'));
      expect(sanitized, isNot(contains('secret123')));
      expect(sanitized, contains('[REDACTED PRIVATE KEY]'));
    });
  });

  group('DebugLogFilter', () {
    final logs = [
      DebugLogEntry(
          id: 1,
          level: DebugLogLevel.debug,
          source: DebugLogSource.app,
          message: 'Debug app',
          timestamp: DateTime.now()),
      DebugLogEntry(
          id: 2,
          level: DebugLogLevel.info,
          source: DebugLogSource.dio,
          message: 'Info dio',
          timestamp: DateTime.now()),
      DebugLogEntry(
          id: 3,
          level: DebugLogLevel.error,
          source: DebugLogSource.app,
          message: 'Error app',
          timestamp: DateTime.now()),
    ];

    test('filter by level', () {
      const state = DebugLogFilterState(levels: {DebugLogLevel.error});
      final filtered = state.apply(logs);
      expect(filtered.length, 1);
      expect(filtered.first.id, 3);
    });

    test('filter by source', () {
      const state = DebugLogFilterState(sources: {DebugLogSource.dio});
      final filtered = state.apply(logs);
      expect(filtered.length, 1);
      expect(filtered.first.id, 2);
    });

    test('search by message', () {
      const state = DebugLogFilterState(searchQuery: 'dio');
      final filtered = state.apply(logs);
      expect(filtered.length, 1);
      expect(filtered.first.message, 'Info dio');
    });
  });

  group('DebugLogExportFormatter', () {
    test('formats empty logs', () {
      final formatted = DebugLogExportFormatter.formatLogs([]);
      expect(formatted, contains('DebugKit Logs'));
      expect(formatted, contains('Total   : 0 entries'));
    });

    test('includes title/date/count', () {
      final logs = [
        DebugLogEntry(
            id: 1,
            level: DebugLogLevel.info,
            source: DebugLogSource.app,
            message: 'Log 1',
            timestamp: DateTime.now()),
      ];
      final formatted = DebugLogExportFormatter.formatLogs(logs);
      expect(formatted, contains('DebugKit Logs'));
      expect(formatted, contains('Exported:'));
      expect(formatted, contains('Total   : 1 entries'));
    });

    test('formats multiple sources and levels', () {
      final logs = [
        DebugLogEntry(
            id: 1,
            level: DebugLogLevel.info,
            source: DebugLogSource.app,
            message: 'App info',
            timestamp: DateTime.now()),
        DebugLogEntry(
            id: 2,
            level: DebugLogLevel.warning,
            source: DebugLogSource.dio,
            message: 'Dio warning',
            timestamp: DateTime.now()),
        DebugLogEntry(
            id: 3,
            level: DebugLogLevel.error,
            source: DebugLogSource.riverpod,
            message: 'Riverpod error',
            timestamp: DateTime.now()),
      ];
      final formatted = DebugLogExportFormatter.formatLogs(logs);
      expect(formatted, contains('Total   : 3 entries'));
      expect(formatted, contains('[INF][APP]'));
      expect(formatted, contains('[WRN][DIO]'));
      expect(formatted, contains('[ERR][RVP]'));
    });

    test('includes metadata in formatted entry', () {
      final entry = DebugLogEntry(
        id: 1,
        level: DebugLogLevel.info,
        source: DebugLogSource.dio,
        message: 'GET /profile',
        timestamp: DateTime.now(),
        metadata: {'status': '200', 'duration_ms': '120'},
      );
      final formatted = DebugLogExportFormatter.formatEntry(entry);
      expect(formatted, contains('Meta:'));
      expect(formatted, contains('status=200'));
      expect(formatted, contains('duration_ms=120'));
    });

    test('includes error and stack trace if present', () {
      final entry = DebugLogEntry(
        id: 1,
        level: DebugLogLevel.error,
        source: DebugLogSource.app,
        message: 'Something failed',
        timestamp: DateTime.now(),
        error: 'NullPointerException',
        stackTrace: '#0 main (main.dart:10)',
      );
      final formatted = DebugLogExportFormatter.formatEntry(entry);
      expect(formatted, contains('Error: NullPointerException'));
      expect(formatted, contains('Stack:'));
      expect(formatted, contains('#0 main'));
    });

    test('includes formatted entries', () {
      final entry = DebugLogEntry(
        id: 1,
        level: DebugLogLevel.info,
        source: DebugLogSource.app,
        message: 'Hello World',
        timestamp: DateTime.now(),
      );
      final formatted = DebugLogExportFormatter.formatEntry(entry);
      expect(formatted, contains('[INF][APP]'));
      expect(formatted, contains('Message: Hello World'));
    });

    test('preserves sanitized values and does not expose raw secrets', () {
      // Simulate what the controller stores after sanitization
      final entry = DebugLogEntry(
        id: 1,
        level: DebugLogLevel.info,
        source: DebugLogSource.app,
        message: 'token is: ab********et', // already sanitized
        timestamp: DateTime.now(),
        metadata: {'api_key': 'ab********et'}, // already sanitized
      );
      final formatted = DebugLogExportFormatter.formatEntry(entry);
      // Sanitized value is preserved
      expect(formatted, contains('ab********et'));
      // Raw secret is not present
      expect(formatted, isNot(contains('abc123secret')));
    });

    test('does not include raw fake secrets in exported output', () {
      // Logs go through controller sanitization before reaching the store.
      // This test verifies the formatter only outputs what is stored.
      final controller = DebugKitController();
      controller.init(enabled: true);
      controller.info('token is: abc123secret');
      controller.info('key='
          '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----');

      final logs = controller.store.logs.toList();
      final formatted = DebugLogExportFormatter.formatLogs(logs);

      expect(formatted, isNot(contains('abc123secret')));
      expect(
          formatted,
          isNot(contains(
              '-----BEGIN PRIVATE KEY-----\nabc123\n-----END PRIVATE KEY-----')));
      expect(formatted, contains('[REDACTED PRIVATE KEY]'));
    });
  });

  group('DebugLogFileExporter', () {
    test('builds safe filename with correct format', () {
      final ts = DateTime(2026, 5, 23, 14, 22, 5);
      final name = DebugLogFileExporter.buildFileName(ts);
      expect(name, 'debugkit-logs-20260523-142205.txt');
    });

    test('filename contains no unsafe filesystem characters', () {
      final name = DebugLogFileExporter.buildFileName(DateTime.now());
      expect(RegExp(r'^[a-z0-9\-\.]+$').hasMatch(name), isTrue);
    });
  });
}
