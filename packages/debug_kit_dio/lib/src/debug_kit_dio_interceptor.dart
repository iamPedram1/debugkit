import 'package:dio/dio.dart';
import 'package:debug_kit/debug_kit.dart';
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
      metadata: {
        'request_id': requestId,
        ...DioLogSanitizerHelpers.sanitizeHeaders(options.headers),
      },
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
      final now = DateTime.now().millisecondsSinceEpoch;
      final durationMs = startedAt != null ? now - startedAt : null;
      final durationStr = durationMs != null ? '${durationMs}ms' : '';

      final method = response.requestOptions.method.toUpperCase();
      final url = DioLogSanitizerHelpers.sanitizeUrl(
          response.requestOptions.uri.toString());
      final statusCode = response.statusCode;

      _controller.updateLogByRequestId(requestId, (entry) {
        return entry.copyWith(
          message: '$method $url · $statusCode · $durationStr',
          metadata: {
            ...entry.metadata ?? {},
            if (durationMs != null) 'duration_ms': durationMs.toString(),
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
      final now = DateTime.now().millisecondsSinceEpoch;
      final durationMs = startedAt != null ? now - startedAt : null;
      final durationStr = durationMs != null ? '${durationMs}ms' : '';

      final method = err.requestOptions.method.toUpperCase();
      final url =
          DioLogSanitizerHelpers.sanitizeUrl(err.requestOptions.uri.toString());

      final isCancelled = err.type == DioExceptionType.cancel;
      final statusLabel = isCancelled ? 'cancelled' : 'failed';
      final statusCode = err.response?.statusCode ?? statusLabel;

      _controller.updateLogByRequestId(requestId, (entry) {
        return entry.copyWith(
          message: '$method $url · $statusCode · $durationStr',
          level: DebugLogLevel.error,
          error: err.toString(),
          metadata: {
            ...entry.metadata ?? {},
            if (durationMs != null) 'duration_ms': durationMs.toString(),
            'error_type': err.type.toString(),
          },
        );
      });
    }

    super.onError(err, handler);
  }
}
