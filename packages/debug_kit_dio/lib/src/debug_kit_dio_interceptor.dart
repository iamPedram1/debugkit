import 'package:dio/dio.dart';
import 'package:debug_kit/debug_kit.dart';
import 'dio_log_sanitizer_helpers.dart';

/// A Dio interceptor that logs network transactions to DebugKit.
///
/// If a request is made inside an active [DebugKit.trace.run] zone, the
/// trace ID and name are automatically attached to the log entry and a
/// network trace event is recorded on the active trace.
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

    // Capture active trace context at request time
    final traceId = _controller.traceController.activeTraceId;
    final traceName = _controller.traceController.activeTraceName;
    if (traceId != null) {
      options.extra['debugKitTraceId'] = traceId;
      options.extra['debugKitTraceName'] = traceName;
    }

    final method = options.method.toUpperCase();
    final url = DioLogSanitizerHelpers.sanitizeUrl(options.uri.toString());

    _controller.log(
      message: '$method $url · pending',
      level: DebugLogLevel.info,
      source: DebugLogSource.dio,
      requestId: requestId,
      traceId: traceId,
      traceName: traceName,
      metadata: {
        'request_id': requestId,
        ...DioLogSanitizerHelpers.sanitizeHeaders(options.headers),
      },
    );

    // Record network event on active trace
    if (traceId != null) {
      _controller.traceController.recordNetworkEvent(
        message: '$method $url · pending',
        requestId: requestId,
        metadata: {'request_id': requestId},
      );
    }

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

      final traceId =
          response.requestOptions.extra['debugKitTraceId'] as String?;

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

      // Update trace event if inside a trace
      if (traceId != null) {
        _controller.traceController.recordNetworkEvent(
          message: '$method $url · $statusCode · $durationStr',
          requestId: requestId,
          durationMs: durationMs,
          metadata: {
            'status_code': statusCode?.toString() ?? '',
            if (durationMs != null) 'duration_ms': durationMs.toString(),
          },
        );
      }
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

      final traceId = err.requestOptions.extra['debugKitTraceId'] as String?;

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

      // Record failed network event on trace
      if (traceId != null) {
        _controller.traceController.recordNetworkEvent(
          message: '$method $url · $statusCode · $durationStr',
          requestId: requestId,
          durationMs: durationMs,
          error: err.toString(),
          metadata: {
            'error_type': err.type.toString(),
            if (durationMs != null) 'duration_ms': durationMs.toString(),
          },
        );
      }
    }

    super.onError(err, handler);
  }
}
