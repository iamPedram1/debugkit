import 'package:dio/dio.dart';
import 'package:debug_kit/debug_kit.dart';
import 'dio_log_sanitizer_helpers.dart';

/// A Dio [Interceptor] that logs network transactions to DebugKit.
///
/// Lifecycle:
/// 1. **[onRequest]**: Creates a pending log entry with the sanitized URL and
///    headers. Assigns a unique `request_id` and records the start timestamp
///    in `options.extra`.
/// 2. **[onResponse]**: Updates the pending log entry (by `request_id`) with
///    the status code, duration, and sanitized response headers.
/// 3. **[onError]**: Updates the pending log entry with the error type, status
///    code (if available), and duration. Sets the level to
///    [DebugLogLevel.error]. Handles Dio cancel exceptions gracefully.
///
/// The "pending → final" update pattern means the console always shows one
/// entry per request, not two separate entries.
///
/// **Trace correlation:** the active Zone trace ID is read once in
/// [onRequest] and stored in `options.extra['debugKitTraceId']`. This
/// snapshot is then used in [onResponse] and [onError] so that the trace is
/// correctly associated even when the response arrives in a different Zone.
class DebugKitDioInterceptor extends Interceptor {
  final DebugKitController _controller;

  /// Per-interceptor counter used to generate unique `request_id` strings.
  ///
  /// Format: `'dio_<n>'` where `n` increments from 1.
  int _idCounter = 0;

  /// Creates a [DebugKitDioInterceptor] backed by [controller].
  DebugKitDioInterceptor(this._controller);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_controller.config.enabled) {
      return super.onRequest(options, handler);
    }

    final requestId = 'dio_${++_idCounter}';
    options.extra['debugKitRequestId'] = requestId;
    options.extra['debugKitStartedAt'] = DateTime.now().millisecondsSinceEpoch;

    // Snapshot the active trace context at request time so it can be used
    // in onResponse / onError even if the Zone changes.
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

    // Record the request start as a network trace event
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

      // Update the pending log entry with the final status
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

      // Record the response as a network trace event
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

      // Update the pending log entry as an error
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

      // Record the failure as a network trace event with an error field
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
