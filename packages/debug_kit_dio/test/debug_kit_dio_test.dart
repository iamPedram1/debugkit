import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_dio/debug_kit_dio.dart';

class MockAdapter implements HttpClientAdapter {
  final ResponseBody response;
  MockAdapter(this.response);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return response;
  }

  @override
  void close({bool force = false}) {}
}

class ErrorMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    throw DioException(
      requestOptions: options,
      error: 'Connection timeout',
      type: DioExceptionType.connectionTimeout,
    );
  }

  @override
  void close({bool force = false}) {}
}

class ErrorWithResponseMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    throw DioException(
      requestOptions: options,
      response: Response(
        requestOptions: options,
        statusCode: 503,
        data: null,
        headers: Headers.fromMap({
          'x-request-id': ['backend-req-error'],
          'x-correlation-id': ['backend-corr-error'],
          'x-trace-id': ['backend-trace-error'],
        }),
      ),
      error: 'Server error',
      type: DioExceptionType.badResponse,
    );
  }

  @override
  void close({bool force = false}) {}
}

class CancelMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio dio;
  late DebugKitController controller;

  setUp(() {
    dio = Dio();
    controller = DebugKitController();
    controller.init(enabled: true);
  });

  test('DebugKitDioAdapter attaches interceptor', () {
    final adapter = DebugKitDioAdapter(dio);
    adapter.attach(controller);
    expect(dio.interceptors.any((i) => i is DebugKitDioInterceptor), isTrue);

    // Repeated attach does not duplicate
    final countBefore = dio.interceptors.length;
    adapter.attach(controller);
    expect(dio.interceptors.length, countBefore);

    adapter.dispose();
    expect(dio.interceptors.any((i) => i is DebugKitDioInterceptor), isFalse);
  });

  test('DebugKitDioInterceptor logs request and response', () async {
    dio.httpClientAdapter = MockAdapter(
      ResponseBody.fromString('{"status":"ok"}', 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'x-request-id': ['backend-req-123'],
        'x-correlation-id': ['backend-corr-456'],
        'x-trace-id': ['backend-trace-789'],
      }),
    );
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await dio.get('https://api.example.com/users?token=secret123');

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, contains('GET https://api.example.com/users?token='));
    expect(log.message, contains('200'));
    expect(log.source, DebugLogSource.dio);

    // Verify metadata
    expect(log.metadata?['request_id'], isNotNull);
    expect(log.metadata?['kind'], 'networkTransaction');
    expect(log.metadata?['method'], 'GET');
    expect(log.metadata?['path'], '/users');
    expect(log.metadata?['phase'], 'completed');
    expect(log.metadata?['status'], '200');
    expect(log.metadata?['duration_ms'], isNotNull);
    expect(log.metadata?['backendRequestId'], 'backend-req-123');
    expect(log.metadata?['backendCorrelationId'], 'backend-corr-456');
    expect(log.metadata?['backendTraceId'], 'backend-trace-789');
  });

  test('DebugKitDioInterceptor logs errors', () async {
    dio.httpClientAdapter = ErrorMockAdapter();
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    try {
      await dio.get('https://api.example.com/users');
    } catch (_) {}

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.level, DebugLogLevel.error);
    expect(log.message, contains('failed'));
    expect(log.metadata?['error_type'], contains('connectionTimeout'));
  });

  test('error responses capture backend correlation metadata in-place',
      () async {
    dio.httpClientAdapter = ErrorWithResponseMockAdapter();
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    try {
      await dio.get('https://api.example.com/users');
    } catch (_) {}

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.level, DebugLogLevel.error);
    expect(log.metadata?['backendRequestId'], 'backend-req-error');
    expect(log.metadata?['backendCorrelationId'], 'backend-corr-error');
    expect(log.metadata?['backendTraceId'], 'backend-trace-error');
  });

  test('DebugKitDioInterceptor handles cancelled requests', () async {
    dio.httpClientAdapter = CancelMockAdapter();
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    try {
      await dio.get('https://api.example.com/users');
    } catch (_) {}

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, contains('cancelled'));
    expect(log.level, DebugLogLevel.error);
  });

  test('captures only allowlisted backend correlation headers', () async {
    dio.httpClientAdapter =
        MockAdapter(ResponseBody.fromString('{}', 200, headers: {
      'authorization': ['Bearer secret'],
      'cookie': ['session=abc'],
      'set-cookie': ['session=abc'],
      'x-request-id': ['backend-req-1'],
      'request-id': ['backend-req-2'],
      'x-correlation-id': ['backend-corr-1'],
      'x-trace-id': ['backend-trace-1'],
      'trace-id': ['backend-trace-2'],
    }));
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await dio.get(
      'https://api.example.com/users',
    );

    final metadata = controller.store.logs.first.metadata!;
    expect(metadata['backendRequestId'], 'backend-req-1');
    expect(metadata['backendCorrelationId'], 'backend-corr-1');
    expect(metadata['backendTraceId'], 'backend-trace-1');
    expect(metadata.containsKey('authorization'), isFalse);
    expect(metadata.containsKey('cookie'), isFalse);
    expect(metadata.containsKey('set-cookie'), isFalse);
  });

  test('truncates backend correlation values to 64 characters', () async {
    final longValue = 'x' * 80;
    dio.httpClientAdapter =
        MockAdapter(ResponseBody.fromString('{}', 200, headers: {
      'x-request-id': [longValue],
    }));
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await dio.get('https://api.example.com/users');

    final metadata = controller.store.logs.first.metadata!;
    expect(metadata['backendRequestId'], isNotNull);
    expect(metadata['backendRequestId']!.length, 64);
  });

  test('Does not log request or response bodies by default', () async {
    final requestBody = {'name': 'John Doe'};
    final responseBody = '{"id": 1, "name": "John Doe"}';

    dio.httpClientAdapter =
        MockAdapter(ResponseBody.fromString(responseBody, 200));
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await dio.post('https://api.example.com/users', data: requestBody);

    final log = controller.store.logs.first;
    expect(log.message, isNot(contains('John Doe')));
    expect(log.details, isNull);
    expect(log.payloadPreview, isNull);
    expect(log.responsePreview, isNull);
  });

  test('respects disabled sanitizer config', () async {
    controller.init(
      enabled: true,
      printToConsole: false,
      sanitizer: const DebugKitSanitizerConfig(
        dangerouslyDisableSanitizer: true,
      ),
    );

    dio.httpClientAdapter = MockAdapter(
      ResponseBody.fromString('{"status":"ok"}', 200),
    );
    dio.interceptors.add(
      DebugKitDioInterceptor(
        controller,
        config: const DebugKitDioConfig(
          captureRequestHeaders: true,
          captureRequestBody: true,
        ),
      ),
    );

    await dio.post(
      'https://api.example.com/users?token=secret123',
      data: {'password': 'super-secret'},
      options: Options(
        headers: {'Authorization': 'Bearer raw-token'},
      ),
    );

    final log = controller.store.logs.first;
    expect(log.message, contains('token=secret123'));
    expect(log.metadata?['requestHeadersPreview'], contains('raw-token'));
    expect(log.metadata?['requestBodyPreview'], contains('super-secret'));
  });

  test('captures safe previews only when explicitly enabled', () async {
    dio.httpClientAdapter = MockAdapter(
      ResponseBody.fromString('{"ok":true}', 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'x-request-id': ['backend-req-preview'],
        'x-secret-header': ['should-not-show'],
      }),
    );
    dio.interceptors.add(
      DebugKitDioInterceptor(
        controller,
        config: const DebugKitDioConfig(
          captureRequestHeaders: true,
          captureResponseHeaders: true,
          captureRequestBody: true,
          captureResponseBody: true,
        ),
      ),
    );

    await dio.post(
      'https://api.example.com/users?token=secret123',
      data: {'password': 'super-secret'},
      options: Options(headers: {
        'Authorization': 'Bearer raw-token',
        'Cookie': 'session=abc',
        'X-Custom': 'value',
      }),
    );

    final log = controller.store.logs.first;
    expect(log.metadata?['requestHeadersPreview'], contains('Authorization'));
    expect(
        log.metadata?['requestHeadersPreview'], isNot(contains('raw-token')));
    expect(
        log.metadata?['requestHeadersPreview'], isNot(contains('session=abc')));
    expect(log.metadata?['requestHeadersPreview'], contains('X-Custom: value'));
    expect(log.metadata?['requestBodyPreview'], contains('password'));
    expect(
        log.metadata?['requestBodyPreview'], isNot(contains('super-secret')));
    expect(log.metadata?['responseHeadersPreview'], contains('content-type'));
    expect(log.metadata?['responseHeadersPreview'],
        isNot(contains('x-secret-header')));
    expect(log.metadata?['responseBodyPreview'], contains('"ok":true'));
    expect(log.metadata?['sanitizedUrl'], contains('token='));
  });

  test('pretty prints JSON previews when enabled', () async {
    dio.httpClientAdapter = MockAdapter(
      ResponseBody.fromString('{"status":"ok","nested":{"count":1}}', 200),
    );
    dio.interceptors.add(
      DebugKitDioInterceptor(
        controller,
        config: const DebugKitDioConfig(
          captureRequestBody: true,
          captureResponseBody: true,
          prettyPrintJson: true,
        ),
      ),
    );

    await dio.post(
      'https://api.example.com/users',
      data: {
        'status': 'ok',
        'nested': {'count': 1}
      },
    );

    final log = controller.store.logs.first;
    expect(log.metadata?['requestBodyPreview'], contains('\n  "nested": {'));
    expect(log.metadata?['responseBodyPreview'], contains('\n  "nested": {'));
  });

  test('decodes gzip-compressed JSON previews when enabled', () async {
    final gzippedRequest = gzip.encode(utf8.encode('{"request":true}'));
    final gzippedResponse = gzip.encode(utf8.encode('{"response":true}'));

    dio.httpClientAdapter = MockAdapter(
      ResponseBody.fromBytes(
        gzippedResponse,
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          Headers.contentEncodingHeader: ['gzip'],
        },
      ),
    );
    dio.interceptors.add(
      DebugKitDioInterceptor(
        controller,
        config: const DebugKitDioConfig(
          captureRequestBody: true,
          captureResponseBody: true,
          prettyPrintJson: true,
          decodeGzipBodies: true,
        ),
      ),
    );

    await dio.post(
      'https://api.example.com/gzip',
      data: gzippedRequest,
      options: Options(headers: {
        Headers.contentTypeHeader: Headers.jsonContentType,
        Headers.contentEncodingHeader: 'gzip',
      }, responseType: ResponseType.bytes),
    );

    final log = controller.store.logs.first;
    expect(log.metadata?['requestBodyPreview'], contains('"request": true'));
    expect(log.metadata?['responseBodyPreview'], contains('"response": true'));
  });

  test('skips large previews even when capture is enabled', () async {
    final largeBody = 'x' * 70000;
    dio.httpClientAdapter =
        MockAdapter(ResponseBody.fromString(largeBody, 200));
    dio.interceptors.add(
      DebugKitDioInterceptor(
        controller,
        config: const DebugKitDioConfig(
          captureRequestBody: true,
          captureResponseBody: true,
          maxBodyBytes: 1024,
        ),
      ),
    );

    await dio.post(
      'https://api.example.com/users',
      data: largeBody,
    );

    final log = controller.store.logs.first;
    expect(log.metadata?['requestBodyPreview'], isNull);
    expect(log.metadata?['responseBodyPreview'], isNull);
    expect(log.metadata?['requestBodySkipReason'], isNotNull);
    expect(log.metadata?['responseBodySkipReason'], isNotNull);
  });

  test('Disabled DebugKit does not log', () async {
    controller.init(enabled: false);
    dio.httpClientAdapter = MockAdapter(ResponseBody.fromString('{}', 200));
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await dio.get('https://api.example.com/users');
    expect(controller.store.logs.isEmpty, isTrue);
  });

  // ---------------------------------------------------------------------------
  // Trace correlation
  // ---------------------------------------------------------------------------
  test('Dio log carries traceId when request is inside active trace', () async {
    controller.init(enabled: true);
    dio.httpClientAdapter = MockAdapter(ResponseBody.fromString('{}', 200));
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await controller.traceController.run('api_flow', () async {
      await dio.get('https://api.example.com/data');
    });

    final log = controller.store.logs.first;
    expect(log.traceId, isNotNull);
    expect(log.traceName, 'api_flow');
  });

  test('Dio log has no traceId when request is outside any trace', () async {
    controller.init(enabled: true);
    dio.httpClientAdapter = MockAdapter(ResponseBody.fromString('{}', 200));
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await dio.get('https://api.example.com/data');

    final log = controller.store.logs.first;
    expect(log.traceId, isNull);
  });

  test('Network trace event is recorded on active trace', () async {
    controller.init(enabled: true);
    dio.httpClientAdapter = MockAdapter(ResponseBody.fromString('{}', 200));
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await controller.traceController.run('api_flow', () async {
      await dio.get('https://api.example.com/data');
    });

    final trace = controller.traceStore.traces.first;
    final networkEvents = trace.events
        .where((e) => e.type == DebugTraceEventType.network)
        .toList();
    expect(networkEvents.isNotEmpty, isTrue);
  });

  test('Disabled mode: no trace events recorded', () async {
    controller.init(enabled: false);
    dio.httpClientAdapter = MockAdapter(ResponseBody.fromString('{}', 200));
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await dio.get('https://api.example.com/data');
    expect(controller.traceStore.traces.isEmpty, isTrue);
  });

  // ---------------------------------------------------------------------------
  // Concurrent request grouping regression tests
  // ---------------------------------------------------------------------------

  group('Concurrent request grouping safety', () {
    test(
        'two identical concurrent pending requests are stored as separate entries',
        () async {
      // Use a manual interceptor and controller directly so we control timing.
      controller.init(enabled: true, groupRepeatedLogs: true);
      final interceptor = DebugKitDioInterceptor(controller);

      // Simulate onRequest for req 1
      final options1 = RequestOptions(path: 'https://api.example.com/users');
      interceptor.onRequest(options1, RequestInterceptorHandler());

      // Simulate onRequest for req 2 (identical URL, same message fingerprint)
      final options2 = RequestOptions(path: 'https://api.example.com/users');
      interceptor.onRequest(options2, RequestInterceptorHandler());

      // Both must be stored as separate rows — not grouped
      expect(controller.store.logs.length, 2,
          reason: 'Each pending network log must be a separate entry so it can '
              'be updated independently by requestId');

      final requestId1 = options1.extra['debugKitRequestId'] as String;
      final requestId2 = options2.extra['debugKitRequestId'] as String;

      expect(requestId1, isNot(requestId2));

      // Both entries must be findable by their own requestId
      final entry1 = controller.store.getEntryByRequestId(requestId1);
      final entry2 = controller.store.getEntryByRequestId(requestId2);
      expect(entry1, isNotNull, reason: 'Entry for req1 must be findable');
      expect(entry2, isNotNull, reason: 'Entry for req2 must be findable');
      expect(entry1!.id, isNot(entry2!.id));
    });

    test('response for req2 updates only req2 entry, req1 entry unchanged',
        () async {
      controller.init(enabled: true, groupRepeatedLogs: true);
      final interceptor = DebugKitDioInterceptor(controller);

      // Fire two identical requests
      final options1 = RequestOptions(path: 'https://api.example.com/feed');
      final options2 = RequestOptions(path: 'https://api.example.com/feed');
      interceptor.onRequest(options1, RequestInterceptorHandler());
      interceptor.onRequest(options2, RequestInterceptorHandler());

      expect(controller.store.logs.length, 2);

      // Response arrives for req2 first (out-of-order)
      final response2 = Response(
        requestOptions: options2,
        statusCode: 200,
        data: null,
      );
      interceptor.onResponse(response2, ResponseInterceptorHandler());

      // req2 entry should now show 200
      final requestId1 = options1.extra['debugKitRequestId'] as String;
      final requestId2 = options2.extra['debugKitRequestId'] as String;

      final updatedEntry2 = controller.store.getEntryByRequestId(requestId2);
      final unchangedEntry1 = controller.store.getEntryByRequestId(requestId1);

      expect(updatedEntry2, isNotNull);
      expect(updatedEntry2!.message, contains('200'),
          reason: 'req2 entry must be updated with status code');

      expect(unchangedEntry1, isNotNull);
      expect(unchangedEntry1!.message, contains('pending'),
          reason:
              'req1 entry must still be pending — not affected by req2 response');
    });

    test(
        'error for req1 updates only req1 entry when responses arrive out-of-order',
        () async {
      controller.init(enabled: true, groupRepeatedLogs: true);
      final interceptor = DebugKitDioInterceptor(controller);

      final options1 = RequestOptions(path: 'https://api.example.com/data');
      final options2 = RequestOptions(path: 'https://api.example.com/data');
      interceptor.onRequest(options1, RequestInterceptorHandler());
      interceptor.onRequest(options2, RequestInterceptorHandler());

      expect(controller.store.logs.length, 2);

      final requestId1 = options1.extra['debugKitRequestId'] as String;
      final requestId2 = options2.extra['debugKitRequestId'] as String;

      // Simulate req2 succeeding via direct store update (same path the adapter uses)
      controller.updateLogByRequestId(
          requestId2,
          (e) => e.copyWith(
                message: 'GET https://api.example.com/data В· 200 В· 10ms',
              ));

      // Simulate req1 failing via direct store update
      controller.updateLogByRequestId(
          requestId1,
          (e) => e.copyWith(
                message: 'GET https://api.example.com/data В· failed В· 5ms',
                level: DebugLogLevel.error,
                error: 'timeout',
              ));

      final entry1 = controller.store.getEntryByRequestId(requestId1);
      final entry2 = controller.store.getEntryByRequestId(requestId2);

      expect(entry1, isNotNull);
      expect(entry1!.level, DebugLogLevel.error,
          reason: 'req1 must be marked as error');
      expect(entry1.message, contains('failed'));

      expect(entry2, isNotNull);
      expect(entry2!.level, DebugLogLevel.info,
          reason:
              'req2 must remain successful, not contaminated by req1 error');
      expect(entry2.message, contains('200'));
    });

    test('store.logs.length stays 2 after both requests complete', () async {
      controller.init(enabled: true, groupRepeatedLogs: true);
      final interceptor = DebugKitDioInterceptor(controller);

      final options1 = RequestOptions(path: 'https://api.example.com/items');
      final options2 = RequestOptions(path: 'https://api.example.com/items');
      interceptor.onRequest(options1, RequestInterceptorHandler());
      interceptor.onRequest(options2, RequestInterceptorHandler());

      final response1 =
          Response(requestOptions: options1, statusCode: 201, data: null);
      final response2 =
          Response(requestOptions: options2, statusCode: 200, data: null);

      interceptor.onResponse(response2, ResponseInterceptorHandler());
      interceptor.onResponse(response1, ResponseInterceptorHandler());

      // No entries evicted, no merging — should still be exactly 2
      expect(controller.store.logs.length, 2);
    });

    test('app logs still group normally alongside non-grouping network logs',
        () async {
      controller.init(enabled: true, groupRepeatedLogs: true);
      final interceptor = DebugKitDioInterceptor(controller);

      // App log repeated 3×
      controller.info('Polling…');
      controller.info('Polling…');
      controller.info('Polling…');

      // Network request (should NOT group with app logs or with each other)
      final options1 = RequestOptions(path: 'https://api.example.com/poll');
      final options2 = RequestOptions(path: 'https://api.example.com/poll');
      interceptor.onRequest(options1, RequestInterceptorHandler());
      interceptor.onRequest(options2, RequestInterceptorHandler());

      // 1 grouped app log + 2 separate network logs = 3 entries
      expect(controller.store.logs.length, 3);
      expect(controller.store.logs.first.repeatCount, 3);
      expect(controller.store.logs.first.source, DebugLogSource.app);
      expect(controller.store.logs[1].source, DebugLogSource.dio);
      expect(controller.store.logs[1].repeatCount, 1);
      expect(controller.store.logs[2].source, DebugLogSource.dio);
      expect(controller.store.logs[2].repeatCount, 1);
    });
  });
}
