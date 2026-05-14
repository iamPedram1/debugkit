import 'package:flutter_test/flutter_test.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/core/controller/debug_kit_controller.dart';
import 'package:debug_kit/src/core/store/debug_log_store.dart';
import 'package:debug_kit/src/utils/sanitizer/debug_log_sanitizer.dart';
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
  });

  group('DebugLogSanitizer', () {
    test('masks bearer tokens', () {
      final sanitized = DebugLogSanitizer.sanitizeMessage('Authorization: Bearer eyJhYmNkZWZ0aGlzaXNhdmVyeWxvbmf0b2tlbiJ9');
      expect(sanitized, contains('eyJh***biJ9'));
    });

    test('masks cookies', () {
      final headers = {'cookie': 'session=1234567890abcdef; other=value'};
      final sanitized = DebugLogSanitizer.sanitizeHeaders(headers);
      expect(sanitized['cookie'], 'sess***alue');
    });

    test('masks API keys', () {
      final sanitized =
          DebugLogSanitizer.sanitizeMessage('api_key=12345678901234567890');
      expect(sanitized, contains('api_key=1234***7890'));
    });

    test('masks passwords', () {
      final sanitized = DebugLogSanitizer.sanitizeMessage('password: secret123');
      expect(sanitized, contains('password:sec***123'));
    });

    test('fully redacts private keys', () {
      const key = '0x1234567890123456789012345678901234567890123456789012345678901234';
      final sanitized = DebugLogSanitizer.sanitizeMessage('My key is $key');
      expect(sanitized, contains('[REDACTED PRIVATE KEY]'));
    });

    test('fully redacts mnemonics', () {
      const mnemonic =
          'apple banana cherry dog elephant fish goat house ice jump kite lemon';
      final sanitized = DebugLogSanitizer.sanitizeMessage('Seed: $mnemonic');
      expect(sanitized, 'Seed: [REDACTED MNEMONIC]');
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
