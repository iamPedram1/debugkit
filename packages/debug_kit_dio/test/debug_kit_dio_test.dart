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
    expect(log.metadata?['duration_ms'], isNotNull);
    expect(log.metadata?['response_headers'], contains('content-type'));
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

  test('Sanitization of headers', () async {
    dio.httpClientAdapter = MockAdapter(ResponseBody.fromString('{}', 200));
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await dio.get(
      'https://api.example.com/users',
      options: Options(headers: {
        'Authorization': 'Bearer secret_token',
        'Cookie': 'session=abc',
        'X-Public': 'public_info',
      }),
    );

    final metadata = controller.store.logs.first.metadata!;
    expect(metadata['Authorization'], contains('***'));
    expect(metadata['Cookie'], contains('***'));
    expect(metadata['X-Public'], 'public_info');
  });

  test('Does not log request or response bodies by default', () async {
    final requestBody = {'name': 'John Doe'};
    final responseBody = '{"id": 1, "name": "John Doe"}';

    dio.httpClientAdapter =
        MockAdapter(ResponseBody.fromString(responseBody, 200));
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await dio.post('https://api.example.com/users', data: requestBody);

    final log = controller.store.logs.first;
    // Message and metadata should not contain the bodies
    expect(log.message, isNot(contains('John Doe')));
    expect(log.details, isNull);
    expect(log.payloadPreview, isNull);
    expect(log.responsePreview, isNull);
  });

  test('Disabled DebugKit does not log', () async {
    controller.init(enabled: false);
    dio.httpClientAdapter = MockAdapter(ResponseBody.fromString('{}', 200));
    dio.interceptors.add(DebugKitDioInterceptor(controller));

    await dio.get('https://api.example.com/users');
    expect(controller.store.logs.isEmpty, isTrue);
  });
}
