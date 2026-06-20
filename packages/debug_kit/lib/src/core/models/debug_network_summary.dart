import 'debug_network_endpoint_stats.dart';
import 'debug_network_status_breakdown.dart';

/// Immutable summary of network behavior observed inside DebugKit.
///
/// Built on demand from sanitized in-memory log entries. Designed to be
/// lightweight, serializable-friendly, and safe for console display or export.
class DebugNetworkSummary {
  final DateTime generatedAt;
  final int slowRequestThresholdMs;
  final int totalRequests;
  final int pendingRequests;
  final int completedRequests;
  final int failedRequests;
  final int slowRequests;
  final int averageDurationMs;
  final int? maxDurationMs;
  final int? minDurationMs;
  final DebugNetworkStatusBreakdown statusBreakdown;
  final List<DebugNetworkEndpointStats> topFailingEndpoints;
  final List<DebugNetworkEndpointStats> slowestEndpoints;
  final List<DebugNetworkEndpointStats> mostCalledEndpoints;

  const DebugNetworkSummary({
    required this.generatedAt,
    required this.slowRequestThresholdMs,
    required this.totalRequests,
    required this.pendingRequests,
    required this.completedRequests,
    required this.failedRequests,
    required this.slowRequests,
    required this.averageDurationMs,
    required this.maxDurationMs,
    required this.minDurationMs,
    required this.statusBreakdown,
    required this.topFailingEndpoints,
    required this.slowestEndpoints,
    required this.mostCalledEndpoints,
  });

  /// Returns `true` when no network transactions were detected.
  bool get isEmpty => totalRequests == 0;

  DebugNetworkSummary.empty({
    this.slowRequestThresholdMs = 500,
  })  : generatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        totalRequests = 0,
        pendingRequests = 0,
        completedRequests = 0,
        failedRequests = 0,
        slowRequests = 0,
        averageDurationMs = 0,
        maxDurationMs = null,
        minDurationMs = null,
        statusBreakdown = const DebugNetworkStatusBreakdown.empty(),
        topFailingEndpoints = const [],
        slowestEndpoints = const [],
        mostCalledEndpoints = const [];
}
