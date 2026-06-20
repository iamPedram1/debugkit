import 'package:dio/dio.dart';
import 'package:debug_kit/debug_kit.dart';
import 'dio_log_sanitizer_helpers.dart';

/// A Dio [Interceptor] that logs network transactions to DebugKit.
///
/// Lifecycle:
/// 1. **[onRequest]**: Creates a pending log entry with the sanitized URL.
///    Assigns a unique `request_id`, captures the request path/method, and
///    records the start timestamp in `options.extra`.
/// 2. **[onResponse]**: Updates the pending log entry (by `request_id`) with
///    the status code, duration, phase, and safe backend correlation IDs from
///    allowlisted response headers.
/// 3. **[onError]**: Updates the pending log entry with the error type, status
///    code (if available), phase, and duration. Sets the level to
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
        'kind': 'networkTransaction',
        'method': method,
        'path': options.uri.path.isEmpty ? '/' : options.uri.path,
        'phase': 'pending',
        'request_id': requestId,
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
      final backendMetadata =
          DioLogSanitizerHelpers.extractBackendCorrelationHeaders(
        response.headers.map,
      );

      final traceId =
          response.requestOptions.extra['debugKitTraceId'] as String?;

      // Update the pending log entry with the final status
      _controller.updateLogByRequestId(requestId, (entry) {
        return entry.copyWith(
          message: '$method $url · $statusCode · $durationStr',
          metadata: {
            ...entry.metadata ?? {},
            'kind': 'networkTransaction',
            'method': method,
            'path': response.requestOptions.uri.path.isEmpty
                ? '/'
                : response.requestOptions.uri.path,
            'phase': 'completed',
            'status': statusCode?.toString() ?? '',
            'status_code': statusCode?.toString() ?? '',
            if (durationMs != null) 'duration_ms': durationMs.toString(),
            if (durationMs != null) 'durationMs': durationMs.toString(),
            ...backendMetadata,
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
            'kind': 'networkTransaction',
            'method': method,
            'path': response.requestOptions.uri.path.isEmpty
                ? '/'
                : response.requestOptions.uri.path,
            'phase': 'completed',
            'status': statusCode?.toString() ?? '',
            'status_code': statusCode?.toString() ?? '',
            if (durationMs != null) 'duration_ms': durationMs.toString(),
            ...backendMetadata,
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
      final backendMetadata = err.response != null
          ? DioLogSanitizerHelpers.extractBackendCorrelationHeaders(
              err.response!.headers.map,
            )
          : <String, String>{};

      final traceId = err.requestOptions.extra['debugKitTraceId'] as String?;

      // Update the pending log entry as an error
      _controller.updateLogByRequestId(requestId, (entry) {
        return entry.copyWith(
          message: '$method $url · $statusCode · $durationStr',
          level: DebugLogLevel.error,
          error: err.toString(),
          metadata: {
            ...entry.metadata ?? {},
            'kind': 'networkTransaction',
            'method': method,
            'path': err.requestOptions.uri.path.isEmpty
                ? '/'
                : err.requestOptions.uri.path,
            'phase': isCancelled ? 'cancelled' : 'failed',
            if (err.response?.statusCode != null)
              'status': err.response!.statusCode.toString(),
            if (err.response?.statusCode != null)
              'status_code': err.response!.statusCode.toString(),
            if (durationMs != null) 'duration_ms': durationMs.toString(),
            if (durationMs != null) 'durationMs': durationMs.toString(),
            'error_type': err.type.toString(),
            ...backendMetadata,
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
            'kind': 'networkTransaction',
            'method': method,
            'path': err.requestOptions.uri.path.isEmpty
                ? '/'
                : err.requestOptions.uri.path,
            'phase': isCancelled ? 'cancelled' : 'failed',
            if (err.response?.statusCode != null)
              'status': err.response!.statusCode.toString(),
            if (err.response?.statusCode != null)
              'status_code': err.response!.statusCode.toString(),
            'error_type': err.type.toString(),
            if (durationMs != null) 'duration_ms': durationMs.toString(),
            if (durationMs != null) 'durationMs': durationMs.toString(),
            ...backendMetadata,
          },
        );
      }
    }

    super.onError(err, handler);
  }
}
