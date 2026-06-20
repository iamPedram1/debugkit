/// Aggregated observability for a single HTTP method + path pair.
///
/// All values are derived from already-sanitized log entries and are safe to
/// export directly.
class DebugNetworkEndpointStats {
  final String method;
  final String path;
  final int totalCount;
  final int completedCount;
  final int failedCount;
  final int slowCount;
  final int status2xx;
  final int status3xx;
  final int status4xx;
  final int status5xx;
  final int statusUnknown;
  final int? averageDurationMs;
  final int? maxDurationMs;
  final int? minDurationMs;
  final int? lastStatusCode;
  final DateTime? lastSeenAt;
  final List<String> relatedTraceIds;
  final List<String> relatedRequestIds;
  final List<String> backendRequestIds;
  final List<String> backendCorrelationIds;
  final List<String> backendTraceIds;

  const DebugNetworkEndpointStats({
    required this.method,
    required this.path,
    required this.totalCount,
    required this.completedCount,
    required this.failedCount,
    required this.slowCount,
    required this.status2xx,
    required this.status3xx,
    required this.status4xx,
    required this.status5xx,
    required this.statusUnknown,
    required this.averageDurationMs,
    required this.maxDurationMs,
    required this.minDurationMs,
    required this.lastStatusCode,
    required this.lastSeenAt,
    this.relatedTraceIds = const [],
    this.relatedRequestIds = const [],
    this.backendRequestIds = const [],
    this.backendCorrelationIds = const [],
    this.backendTraceIds = const [],
  });
}
