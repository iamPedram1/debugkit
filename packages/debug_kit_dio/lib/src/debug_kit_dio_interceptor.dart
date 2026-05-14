import 'package:dio/dio.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/core/controller/debug_kit_controller.dart';
import 'dio_log_sanitizer_helpers.dart';

/// A Dio interceptor that logs network transactions to DebugKit.
class DebugKitDioInterceptor extends Interceptor {
  final DebugKitController _controller;
  int _idCounter = 0;

  DebugKitDioInterceptor(this._controller);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_controller.config.enabled) {
      return super.onRequest(options, handler);
    }

    final requestId = 'dio_${++_idCounter}';
    options.extra['debugKitRequestId'] = requestId;
    options.extra['debugKitStartedAt'] = DateTime.now().millisecondsSinceEpoch;

    final method = options.method.toUpperCase();
    final url = DioLogSanitizerHelpers.sanitizeUrl(options.uri.toString());

    _controller.log(
      message: '$method $url · pending',
      level: DebugLogLevel.info,
      source: DebugLogSource.dio,
      requestId: requestId,
      metadata: DioLogSanitizerHelpers.sanitizeHeaders(options.headers),
    );

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_controller.config.enabled) {
      return super.onResponse(response, handler);
    }

    final requestId =
        response.requestOptions.extra['debugKitRequestId'] as String?;
    if (requestId != null) {
      final startedAt =
          response.requestOptions.extra['debugKitStartedAt'] as int?;
      final duration = startedAt != null
          ? '${DateTime.now().millisecondsSinceEpoch - startedAt}ms'
          : '';

      final method = response.requestOptions.method.toUpperCase();
      final url = DioLogSanitizerHelpers.sanitizeUrl(
          response.requestOptions.uri.toString());
      final statusCode = response.statusCode;

      _controller.updateLogByRequestId(requestId, (entry) {
        return entry.copyWith(
          message: '$method $url · $statusCode · $duration',
          metadata: {
            ...entry.metadata ?? {},
            'response_headers':
                DioLogSanitizerHelpers.sanitizeHeaders(response.headers.map)
                    .toString(),
          },
        );
      });
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_controller.config.enabled) {
      return super.onError(err, handler);
    }

    final requestId = err.requestOptions.extra['debugKitRequestId'] as String?;
    if (requestId != null) {
      final startedAt = err.requestOptions.extra['debugKitStartedAt'] as int?;
      final duration = startedAt != null
          ? '${DateTime.now().millisecondsSinceEpoch - startedAt}ms'
          : '';

      final method = err.requestOptions.method.toUpperCase();
      final url =
          DioLogSanitizerHelpers.sanitizeUrl(err.requestOptions.uri.toString());
      final statusCode = err.response?.statusCode ?? 'failed';

      _controller.updateLogByRequestId(requestId, (entry) {
        return entry.copyWith(
          message: '$method $url · $statusCode · $duration',
          level: DebugLogLevel.error,
          error: err.toString(),
          metadata: {
            ...entry.metadata ?? {},
            'error_type': err.type.toString(),
          },
        );
      });
    }

    super.onError(err, handler);
  }
}
