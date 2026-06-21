import 'package:intl/intl.dart';

import 'debug_network_status_family.dart';
import 'debug_network_transaction_phase.dart';

/// Immutable representation of a single network transaction.
///
/// Built from a sanitized DebugKit log entry. It intentionally stays generic
/// so adapter packages can feed it without the core depending on Dio or any
/// other transport library.
class DebugNetworkTransaction {
  /// Backing log entry ID.
  final int logEntryId;

  /// Request lifecycle identifier used by adapters to update a single entry.
  final String? requestId;

  /// Correlated trace ID, if the request happened inside a trace zone.
  final String? traceId;

  /// Human-readable trace name.
  final String? traceName;

  /// Step index within the trace, when provided.
  final int? traceStep;

  /// HTTP method such as GET, POST, or PATCH.
  final String method;

  /// Fully sanitized URL, if available.
  final String? url;

  /// Sanitized host, if available.
  final String? host;

  /// Normalized request path without query parameters.
  final String path;

  /// Sanitized query string without the leading `?`, if available.
  final String? query;

  /// When the request started.
  final DateTime startedAt;

  /// Alias for [startedAt] so callers can use either terminology.
  DateTime get timestamp => startedAt;

  /// Sanitized response status code, if available.
  final int? statusCode;

  /// Response status family derived from [statusCode].
  final DebugNetworkStatusFamily statusFamily;

  /// Round-trip duration in milliseconds.
  final int? durationMs;

  /// Current transaction phase.
  final DebugNetworkTransactionPhase phase;

  /// Sanitized error type, if available.
  final String? errorType;

  /// Sanitized error message, if available.
  final String? errorMessage;

  /// Sanitized stack trace when available from a failed transaction.
  final String? stackTrace;

  /// Backend request identifier captured from response headers, if any.
  final String? backendRequestId;

  /// Backend correlation identifier captured from response headers, if any.
  final String? backendCorrelationId;

  /// Backend trace identifier captured from response headers, if any.
  final String? backendTraceId;

  /// Additional sanitized metadata to preserve for details / export.
  final Map<String, String> metadata;

  /// Optional sanitized request header preview captured by the adapter.
  final String? requestHeadersPreview;

  /// Optional sanitized response header preview captured by the adapter.
  final String? responseHeadersPreview;

  /// Optional sanitized request body preview captured by the adapter.
  final String? requestBodyPreview;

  /// Optional sanitized response body preview captured by the adapter.
  final String? responseBodyPreview;

  const DebugNetworkTransaction({
    required this.logEntryId,
    required this.method,
    required this.path,
    required this.startedAt,
    required this.statusFamily,
    required this.phase,
    this.requestId,
    this.traceId,
    this.traceName,
    this.traceStep,
    this.url,
    this.host,
    this.query,
    this.statusCode,
    this.durationMs,
    this.errorType,
    this.errorMessage,
    this.stackTrace,
    this.backendRequestId,
    this.backendCorrelationId,
    this.backendTraceId,
    this.metadata = const {},
    this.requestHeadersPreview,
    this.responseHeadersPreview,
    this.requestBodyPreview,
    this.responseBodyPreview,
  });

  /// Stable string ID derived from [logEntryId].
  String get id => 'log_$logEntryId';

  /// Returns `true` when the transaction is still pending.
  bool get isPending => phase == DebugNetworkTransactionPhase.pending;

  /// Returns `true` when the transaction completed successfully.
  bool get isCompleted => phase == DebugNetworkTransactionPhase.completed;

  /// Returns `true` when the transaction failed or was cancelled.
  bool get isFailed =>
      phase == DebugNetworkTransactionPhase.failed ||
      phase == DebugNetworkTransactionPhase.cancelled;

  /// Returns `true` when the request duration is at or above [thresholdMs].
  bool isSlow(int thresholdMs) =>
      durationMs != null && durationMs! >= thresholdMs;

  /// Human-readable phase/status label for compact UI chips.
  String get statusLabel {
    if (statusCode != null) return '$statusCode';
    return phase.label;
  }

  /// Returns the request path, optionally with the sanitized query string.
  String get displayPath {
    if (query == null || query!.isEmpty) return path;
    return '$path?$query';
  }

  /// Human-readable duration label.
  String get durationLabel => durationMs == null ? 'n/a' : '${durationMs}ms';

  /// Human-readable start timestamp label.
  String get startedAtLabel => DateFormat('HH:mm:ss').format(startedAt);

  /// Human-readable completion timestamp label, if available.
  String? get completedAtLabel =>
      completedAt == null ? null : DateFormat('HH:mm:ss').format(completedAt!);

  /// Derived completion time, if the transaction has a duration.
  DateTime? get completedAt => durationMs == null
      ? null
      : startedAt.add(Duration(milliseconds: durationMs!));

  /// Returns the best available error summary, or `null`.
  String? get errorSummary => errorMessage ?? errorType;

  DebugNetworkTransaction copyWith({
    int? logEntryId,
    String? requestId,
    String? traceId,
    String? traceName,
    int? traceStep,
    String? method,
    String? url,
    String? host,
    String? path,
    String? query,
    DateTime? startedAt,
    int? statusCode,
    DebugNetworkStatusFamily? statusFamily,
    int? durationMs,
    DebugNetworkTransactionPhase? phase,
    String? errorType,
    String? errorMessage,
    String? stackTrace,
    String? backendRequestId,
    String? backendCorrelationId,
    String? backendTraceId,
    Map<String, String>? metadata,
    String? requestHeadersPreview,
    String? responseHeadersPreview,
    String? requestBodyPreview,
    String? responseBodyPreview,
  }) {
    return DebugNetworkTransaction(
      logEntryId: logEntryId ?? this.logEntryId,
      requestId: requestId ?? this.requestId,
      traceId: traceId ?? this.traceId,
      traceName: traceName ?? this.traceName,
      traceStep: traceStep ?? this.traceStep,
      method: method ?? this.method,
      url: url ?? this.url,
      host: host ?? this.host,
      path: path ?? this.path,
      query: query ?? this.query,
      startedAt: startedAt ?? this.startedAt,
      statusCode: statusCode ?? this.statusCode,
      statusFamily: statusFamily ?? this.statusFamily,
      durationMs: durationMs ?? this.durationMs,
      phase: phase ?? this.phase,
      errorType: errorType ?? this.errorType,
      errorMessage: errorMessage ?? this.errorMessage,
      stackTrace: stackTrace ?? this.stackTrace,
      backendRequestId: backendRequestId ?? this.backendRequestId,
      backendCorrelationId: backendCorrelationId ?? this.backendCorrelationId,
      backendTraceId: backendTraceId ?? this.backendTraceId,
      metadata: metadata ?? this.metadata,
      requestHeadersPreview:
          requestHeadersPreview ?? this.requestHeadersPreview,
      responseHeadersPreview:
          responseHeadersPreview ?? this.responseHeadersPreview,
      requestBodyPreview: requestBodyPreview ?? this.requestBodyPreview,
      responseBodyPreview: responseBodyPreview ?? this.responseBodyPreview,
    );
  }
}
