import 'package:flutter_test/flutter_test.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/core/store/debug_log_store.dart';
import 'package:debug_kit/src/utils/export/debug_log_export_formatter.dart';
import 'package:debug_kit/src/utils/filtering/debug_log_filter.dart';

void main() {
  group('DebugLogStore', () {
    test('appends logs', () {
      final store = DebugLogStore(maxLogs: 10);
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
      final store = DebugLogStore(maxLogs: 3);
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
      final store = DebugLogStore(maxLogs: 10);
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
      controller.init(enabled: true);
      controller.info(
          'App started with key=0x1234567890123456789012345678901234567890123456789012345678901234');

      expect(controller.store.logs.length, 1);
      final entry = controller.store.logs.first;
      expect(entry.message, contains('[REDACTED PRIVATE KEY]'));
      expect(entry.level, DebugLogLevel.info);
      expect(entry.source, DebugLogSource.app);
    });
  });

  group('DebugKit facade', () {
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
          'Authorization: Bearer eyJhYmNkZWZ0aGlzaXNhdmVyeWxvbmf0b2tlbiJ9');
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

    test('fully redacts private keys', () {
      const key =
          '0x1234567890123456789012345678901234567890123456789012345678901234';
      final sanitized = DebugLogSanitizer.sanitizeMessage('My key is $key');
      expect(sanitized, contains('[REDACTED PRIVATE KEY]'));
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
  });
}
