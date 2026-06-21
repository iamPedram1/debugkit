import 'package:debug_kit/debug_kit.dart';
import 'package:dio/dio.dart';

import 'debug_kit_dio_config.dart';
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
  final DebugKitDioConfig config;

  /// Per-interceptor counter used to generate unique `request_id` strings.
  ///
  /// Format: `'dio_<n>'` where `n` increments from 1.
  int _idCounter = 0;

  /// Creates a [DebugKitDioInterceptor] backed by [controller].
  DebugKitDioInterceptor(this._controller,
      {this.config = const DebugKitDioConfig()});

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
    final sanitizedUrl =
        DioLogSanitizerHelpers.sanitizeUrl(options.uri.toString());
    final requestHeadersPreview =
        DioLogSanitizerHelpers.buildRequestHeadersPreview(
      options.headers,
      captureHeaders: config.captureRequestHeaders,
      maxPreviewChars: config.maxBodyPreviewChars,
    );
    final requestBodyPreview = DioLogSanitizerHelpers.buildBodyPreview(
      options.data,
      captureBody: config.captureRequestBody,
      maxCaptureBytes: config.maxCaptureBytes,
      maxPreviewChars: config.maxBodyPreviewChars,
    );
    final path = options.uri.path.isEmpty ? '/' : options.uri.path;
    final parsedSanitizedUri = Uri.tryParse(sanitizedUrl);
    final normalizedQuery = (parsedSanitizedUri?.query.isNotEmpty ?? false)
        ? parsedSanitizedUri!.query
        : null;
    final host = options.uri.host.isEmpty ? null : options.uri.host;
    final baseMetadata = <String, String>{
      'kind': 'networkTransaction',
      'method': method,
      'path': path,
      if (sanitizedUrl.isNotEmpty) 'sanitizedUrl': sanitizedUrl,
      if (sanitizedUrl.isNotEmpty) 'url': sanitizedUrl,
      if (normalizedQuery != null && normalizedQuery.isNotEmpty)
        'query': normalizedQuery,
      if (host != null && host.isNotEmpty) 'host': host,
      'phase': 'pending',
      'request_id': requestId,
      'requestId': requestId,
      if (requestHeadersPreview != null)
        'requestHeadersPreview': requestHeadersPreview,
      if (requestBodyPreview != null) 'requestBodyPreview': requestBodyPreview,
    };

    _controller.log(
      message: '$method $sanitizedUrl · pending',
      level: DebugLogLevel.info,
      source: DebugLogSource.dio,
      requestId: requestId,
      traceId: traceId,
      traceName: traceName,
      metadata: baseMetadata,
    );

    // Record the request start as a network trace event
    if (traceId != null) {
      _controller.traceController.recordNetworkEvent(
        message: '$method $sanitizedUrl · pending',
        requestId: requestId,
        metadata: baseMetadata,
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
      final path = response.requestOptions.uri.path.isEmpty
          ? '/'
          : response.requestOptions.uri.path;
      final parsedSanitizedUri = Uri.tryParse(url);
      final normalizedQuery = (parsedSanitizedUri?.query.isNotEmpty ?? false)
          ? parsedSanitizedUri!.query
          : null;
      final host = response.requestOptions.uri.host.isEmpty
          ? null
          : response.requestOptions.uri.host;
      final statusCode = response.statusCode;
      final backendMetadata =
          DioLogSanitizerHelpers.extractBackendCorrelationHeaders(
        response.headers.map,
      );
      final responseHeadersPreview =
          DioLogSanitizerHelpers.buildResponseHeadersPreview(
        response.headers.map,
        captureHeaders: config.captureResponseHeaders,
        maxPreviewChars: config.maxBodyPreviewChars,
      );
      final responseBodyPreview = DioLogSanitizerHelpers.buildBodyPreview(
        response.data,
        captureBody: config.captureResponseBody,
        maxCaptureBytes: config.maxCaptureBytes,
        maxPreviewChars: config.maxBodyPreviewChars,
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
            'path': path,
            if (url.isNotEmpty) 'sanitizedUrl': url,
            if (url.isNotEmpty) 'url': url,
            if (normalizedQuery != null && normalizedQuery.isNotEmpty)
              'query': normalizedQuery,
            if (host != null && host.isNotEmpty) 'host': host,
            'phase': 'completed',
            'status': statusCode?.toString() ?? '',
            'status_code': statusCode?.toString() ?? '',
            if (durationMs != null) 'duration_ms': durationMs.toString(),
            if (durationMs != null) 'durationMs': durationMs.toString(),
            if (responseHeadersPreview != null)
              'responseHeadersPreview': responseHeadersPreview,
            if (responseBodyPreview != null)
              'responseBodyPreview': responseBodyPreview,
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
            'path': path,
            if (url.isNotEmpty) 'sanitizedUrl': url,
            if (normalizedQuery != null && normalizedQuery.isNotEmpty)
              'query': normalizedQuery,
            if (host != null && host.isNotEmpty) 'host': host,
            'phase': 'completed',
            'status': statusCode?.toString() ?? '',
            'status_code': statusCode?.toString() ?? '',
            if (durationMs != null) 'duration_ms': durationMs.toString(),
            if (responseHeadersPreview != null)
              'responseHeadersPreview': responseHeadersPreview,
            if (responseBodyPreview != null)
              'responseBodyPreview': responseBodyPreview,
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
      final path = err.requestOptions.uri.path.isEmpty
          ? '/'
          : err.requestOptions.uri.path;
      final parsedSanitizedUri = Uri.tryParse(url);
      final normalizedQuery = (parsedSanitizedUri?.query.isNotEmpty ?? false)
          ? parsedSanitizedUri!.query
          : null;
      final host = err.requestOptions.uri.host.isEmpty
          ? null
          : err.requestOptions.uri.host;

      final isCancelled = err.type == DioExceptionType.cancel;
      final statusLabel = isCancelled ? 'cancelled' : 'failed';
      final statusCode = err.response?.statusCode ?? statusLabel;
      final backendMetadata = err.response != null
          ? DioLogSanitizerHelpers.extractBackendCorrelationHeaders(
              err.response!.headers.map,
            )
          : <String, String>{};
      final responseHeadersPreview = err.response != null
          ? DioLogSanitizerHelpers.buildResponseHeadersPreview(
              err.response!.headers.map,
              captureHeaders: config.captureResponseHeaders,
              maxPreviewChars: config.maxBodyPreviewChars,
            )
          : null;
      final responseBodyPreview = err.response != null
          ? DioLogSanitizerHelpers.buildBodyPreview(
              err.response!.data,
              captureBody: config.captureResponseBody,
              maxCaptureBytes: config.maxCaptureBytes,
              maxPreviewChars: config.maxBodyPreviewChars,
            )
          : null;
      final errorMessage = DebugLogSanitizer.sanitizeMessage(
        err.message ?? err.error?.toString() ?? err.toString(),
      );
      final sanitizedStackTrace = DebugLogSanitizer.trimStackTrace(
        DebugLogSanitizer.sanitizeMessage(err.stackTrace.toString()),
      );

      final traceId = err.requestOptions.extra['debugKitTraceId'] as String?;

      // Update the pending log entry as an error
      _controller.updateLogByRequestId(requestId, (entry) {
        return entry.copyWith(
          message: '$method $url · $statusCode · $durationStr',
          level: DebugLogLevel.error,
          error: errorMessage,
          stackTrace: sanitizedStackTrace,
          metadata: {
            ...entry.metadata ?? {},
            'kind': 'networkTransaction',
            'method': method,
            'path': path,
            if (url.isNotEmpty) 'sanitizedUrl': url,
            if (url.isNotEmpty) 'url': url,
            if (normalizedQuery != null && normalizedQuery.isNotEmpty)
              'query': normalizedQuery,
            if (host != null && host.isNotEmpty) 'host': host,
            'phase': isCancelled ? 'cancelled' : 'failed',
            if (err.response?.statusCode != null)
              'status': err.response!.statusCode.toString(),
            if (err.response?.statusCode != null)
              'status_code': err.response!.statusCode.toString(),
            if (durationMs != null) 'duration_ms': durationMs.toString(),
            if (durationMs != null) 'durationMs': durationMs.toString(),
            'errorType': err.type.toString(),
            'error_type': err.type.toString(),
            'errorMessage': errorMessage,
            'error_message': errorMessage,
            if (responseHeadersPreview != null)
              'responseHeadersPreview': responseHeadersPreview,
            if (responseBodyPreview != null)
              'responseBodyPreview': responseBodyPreview,
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
          error: errorMessage,
          metadata: {
            'kind': 'networkTransaction',
            'method': method,
            'path': path,
            if (url.isNotEmpty) 'sanitizedUrl': url,
            if (normalizedQuery != null && normalizedQuery.isNotEmpty)
              'query': normalizedQuery,
            if (host != null && host.isNotEmpty) 'host': host,
            'phase': isCancelled ? 'cancelled' : 'failed',
            if (err.response?.statusCode != null)
              'status': err.response!.statusCode.toString(),
            if (err.response?.statusCode != null)
              'status_code': err.response!.statusCode.toString(),
            'errorType': err.type.toString(),
            'error_type': err.type.toString(),
            'errorMessage': errorMessage,
            'error_message': errorMessage,
            if (durationMs != null) 'duration_ms': durationMs.toString(),
            if (durationMs != null) 'durationMs': durationMs.toString(),
            if (responseHeadersPreview != null)
              'responseHeadersPreview': responseHeadersPreview,
            if (responseBodyPreview != null)
              'responseBodyPreview': responseBodyPreview,
            ...backendMetadata,
          },
        );
      }
    }

    super.onError(err, handler);
  }
}
