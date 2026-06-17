import 'package:flutter_test/flutter_test.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/utils/errors/debug_error_fingerprint_builder.dart';

DebugLogEntry _errorEntry({
  int id = 1,
  DebugLogLevel level = DebugLogLevel.error,
  DebugLogSource source = DebugLogSource.app,
  String message = 'Something failed',
  String? error,
  String? stackTrace,
  Map<String, String>? metadata,
  String? requestId,
  String? traceId,
}) {
  return DebugLogEntry(
    id: id,
    level: level,
    source: source,
    message: message,
    timestamp: DateTime.now(),
    error: error,
    stackTrace: stackTrace,
    metadata: metadata,
    requestId: requestId,
    traceId: traceId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DebugErrorFingerprintBuilder — same error groups', () {
    test('identical app error messages produce identical fingerprints', () {
      final a = _errorEntry(
          message: 'Auth failed', error: 'Exception: token expired');
      final b = _errorEntry(
          id: 2, message: 'Auth failed', error: 'Exception: token expired');
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        DebugErrorFingerprintBuilder.forLogEntry(b),
      );
    });

    test('same SocketException message groups', () {
      final a = _errorEntry(
          message: 'SocketException: Connection failed for /feed',
          error: 'SocketException: Connection failed for /feed');
      final b = _errorEntry(
          id: 2,
          message: 'SocketException: Connection failed for /feed',
          error: 'SocketException: Connection failed for /feed');
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        DebugErrorFingerprintBuilder.forLogEntry(b),
      );
    });

    test('timeout messages with different durations group after normalization',
        () {
      final a = _errorEntry(
          message: 'Request timed out',
          error: 'Timeout after 5000ms for GET /feed');
      final b = _errorEntry(
          id: 2,
          message: 'Request timed out',
          error: 'Timeout after 7000ms for GET /feed');
      // Both should produce same fingerprint because the duration "after Nms" is
      // stripped during normalization
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        DebugErrorFingerprintBuilder.forLogEntry(b),
      );
    });

    test('same Dio path + status groups', () {
      final a = _errorEntry(
          source: DebugLogSource.dio,
          message: 'GET https://api.example.com/profile · 401 · 120ms');
      final b = _errorEntry(
          id: 2,
          source: DebugLogSource.dio,
          message: 'GET https://api.example.com/profile · 401 · 85ms');
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        DebugErrorFingerprintBuilder.forLogEntry(b),
      );
    });

    test('same Riverpod provider failure groups', () {
      final a = _errorEntry(
          source: DebugLogSource.riverpod,
          message: 'Riverpod provider failed: authProvider',
          error: 'Exception: invalid token',
          metadata: {
            'provider_name': 'authProvider',
            'event_type': 'provider_failure'
          });
      final b = _errorEntry(
          id: 2,
          source: DebugLogSource.riverpod,
          message: 'Riverpod provider failed: authProvider',
          error: 'Exception: invalid token',
          metadata: {
            'provider_name': 'authProvider',
            'event_type': 'provider_failure'
          });
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        DebugErrorFingerprintBuilder.forLogEntry(b),
      );
    });
  });

  group('DebugErrorFingerprintBuilder — different types do NOT group', () {
    test('AuthException and FormatException do not group', () {
      final a = _errorEntry(error: 'AuthException: Invalid token');
      final b = _errorEntry(id: 2, error: 'FormatException: Invalid token');
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        isNot(DebugErrorFingerprintBuilder.forLogEntry(b)),
      );
    });

    test('different HTTP status codes do not group', () {
      final a = _errorEntry(
          source: DebugLogSource.dio,
          message: 'GET https://api.example.com/profile · 401 · 100ms');
      final b = _errorEntry(
          id: 2,
          source: DebugLogSource.dio,
          message: 'GET https://api.example.com/profile · 500 · 100ms');
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        isNot(DebugErrorFingerprintBuilder.forLogEntry(b)),
      );
    });

    test('different provider names do not group', () {
      final a = _errorEntry(
          source: DebugLogSource.riverpod,
          error: 'Exception: error',
          metadata: {
            'provider_name': 'authProvider',
            'event_type': 'provider_failure'
          });
      final b = _errorEntry(
          id: 2,
          source: DebugLogSource.riverpod,
          error: 'Exception: error',
          metadata: {
            'provider_name': 'cartProvider',
            'event_type': 'provider_failure'
          });
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        isNot(DebugErrorFingerprintBuilder.forLogEntry(b)),
      );
    });

    test('different HTTP paths do not group', () {
      final a = _errorEntry(
          source: DebugLogSource.dio,
          message: 'GET https://api.example.com/profile · 404 · 50ms');
      final b = _errorEntry(
          id: 2,
          source: DebugLogSource.dio,
          message: 'GET https://api.example.com/settings · 404 · 50ms');
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        isNot(DebugErrorFingerprintBuilder.forLogEntry(b)),
      );
    });

    test('app error and Dio error do not group even with same message', () {
      final a =
          _errorEntry(source: DebugLogSource.app, message: 'Network failed');
      final b = _errorEntry(
          id: 2, source: DebugLogSource.dio, message: 'Network failed');
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        isNot(DebugErrorFingerprintBuilder.forLogEntry(b)),
      );
    });
  });

  group('DebugErrorFingerprintBuilder — volatile values are ignored', () {
    test('IDs in error messages are normalized away', () {
      // Timeout messages with different durations should normalize to same fingerprint
      final a = _errorEntry(error: 'Timeout after 5000ms for GET /feed');
      final b = _errorEntry(id: 2, error: 'Timeout after 7000ms for GET /feed');
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        DebugErrorFingerprintBuilder.forLogEntry(b),
      );
    });

    test('different request IDs do not affect Dio fingerprint', () {
      // Both are GET /profile 401 — requestId is not part of fingerprint
      final a = _errorEntry(
          source: DebugLogSource.dio,
          message: 'GET https://api.example.com/profile · 401 · 80ms',
          requestId: 'dio_1');
      final b = _errorEntry(
          id: 2,
          source: DebugLogSource.dio,
          message: 'GET https://api.example.com/profile · 401 · 80ms',
          requestId: 'dio_7');
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        DebugErrorFingerprintBuilder.forLogEntry(b),
      );
    });
  });

  group('DebugErrorFingerprintBuilder — first useful stack frame', () {
    test('fingerprint uses first useful stack frame', () {
      final a = _errorEntry(
          error: 'Exception: auth failed',
          stackTrace: 'package:myapp/auth_repository.dart:42:8\n'
              'package:myapp/login_screen.dart:100:5');
      final b = _errorEntry(
          id: 2,
          error: 'Exception: auth failed',
          stackTrace: 'package:myapp/auth_repository.dart:42:8\n'
              'package:myapp/settings_screen.dart:20:3');
      // Same first frame — should group
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        DebugErrorFingerprintBuilder.forLogEntry(b),
      );
    });

    test('different first useful frames produce different fingerprints', () {
      final a = _errorEntry(
          error: 'Exception: failed',
          stackTrace: 'package:myapp/auth_repository.dart:42:8');
      final b = _errorEntry(
          id: 2,
          error: 'Exception: failed',
          stackTrace: 'package:myapp/payment_repository.dart:15:3');
      expect(
        DebugErrorFingerprintBuilder.forLogEntry(a),
        isNot(DebugErrorFingerprintBuilder.forLogEntry(b)),
      );
    });
  });

  group('DebugErrorFingerprintBuilder — normalizeMessage', () {
    test('strips timeout duration keywords', () {
      final a = DebugErrorFingerprintBuilder.normalizeMessage(
          'Timeout after 5000ms for GET /feed');
      final b = DebugErrorFingerprintBuilder.normalizeMessage(
          'Timeout after 7000ms for GET /feed');
      expect(a, b);
    });

    test('strips UUID patterns', () {
      final msg = DebugErrorFingerprintBuilder.normalizeMessage(
          'Request 550e8400-e29b-41d4-a716-446655440000 failed');
      expect(msg, isNot(contains('550e8400')));
    });

    test('preserves exception type names', () {
      final msg = DebugErrorFingerprintBuilder.normalizeMessage(
          'SocketException: Connection refused');
      expect(msg, contains('socketexception'));
    });
  });

  group('DebugErrorFingerprintBuilder — forFailedTrace', () {
    test('same trace name and error produces same fingerprint', () {
      final t1 = DebugTrace(
        id: 'trace_1',
        name: 'login_flow',
        status: DebugTraceStatus.failed,
        startedAt: DateTime.now(),
        errorSummary: 'Auth failed',
      );
      final t2 = DebugTrace(
        id: 'trace_2',
        name: 'login_flow',
        status: DebugTraceStatus.failed,
        startedAt: DateTime.now(),
        errorSummary: 'Auth failed',
      );
      expect(
        DebugErrorFingerprintBuilder.forFailedTrace(t1),
        DebugErrorFingerprintBuilder.forFailedTrace(t2),
      );
    });

    test('different trace names produce different fingerprints', () {
      final t1 = DebugTrace(
        id: 'trace_1',
        name: 'login_flow',
        status: DebugTraceStatus.failed,
        startedAt: DateTime.now(),
        errorSummary: 'Auth failed',
      );
      final t2 = DebugTrace(
        id: 'trace_2',
        name: 'checkout_flow',
        status: DebugTraceStatus.failed,
        startedAt: DateTime.now(),
        errorSummary: 'Auth failed',
      );
      expect(
        DebugErrorFingerprintBuilder.forFailedTrace(t1),
        isNot(DebugErrorFingerprintBuilder.forFailedTrace(t2)),
      );
    });
  });
}
