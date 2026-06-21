import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_network_endpoint_stats.dart';
import '../../core/models/debug_network_status_breakdown.dart';
import '../../core/models/debug_network_summary.dart';
import '../../core/models/debug_network_transaction.dart';
import '../../core/models/debug_network_status_family.dart';
import 'debug_network_transaction_builder.dart';

/// Pure builder that derives a [DebugNetworkSummary] from sanitized log data.
///
/// Only entries that look like network transactions are considered. Malformed
/// metadata is ignored safely.
class DebugNetworkSummaryBuilder {
  DebugNetworkSummaryBuilder._();

  static const int _maxRelatedIds = 10;
  static const int _maxTopEndpoints = 5;

  static DebugNetworkSummary build(
    List<DebugLogEntry> logs, {
    int slowRequestThresholdMs = 500,
  }) {
    final transactions = DebugNetworkTransactionBuilder.build(logs);
    return buildFromTransactions(
      transactions,
      slowRequestThresholdMs: slowRequestThresholdMs,
    );
  }

  static DebugNetworkSummary buildFromTransactions(
    List<DebugNetworkTransaction> transactions, {
    int slowRequestThresholdMs = 500,
  }) {
    final endpointMap = <String, _EndpointAccumulator>{};

    var totalRequests = 0;
    var pendingRequests = 0;
    var completedRequests = 0;
    var failedRequests = 0;
    var slowRequests = 0;
    var totalDurationMs = 0;
    var durationSamples = 0;
    int? maxDurationMs;
    int? minDurationMs;

    var status2xx = 0;
    var status3xx = 0;
    var status4xx = 0;
    var status5xx = 0;
    var statusUnknown = 0;

    for (final transaction in transactions) {
      final method = transaction.method;
      final path = transaction.path;
      final key = '$method|$path';
      final acc = endpointMap.putIfAbsent(
        key,
        () => _EndpointAccumulator(method: method, path: path),
      );

      totalRequests += 1;
      acc.totalCount += 1;

      final statusCode = transaction.statusCode;
      final durationMs = transaction.durationMs;

      if (transaction.isPending) {
        pendingRequests += 1;
      } else if (transaction.isFailed) {
        failedRequests += 1;
        acc.failedCount += 1;
      } else {
        completedRequests += 1;
        acc.completedCount += 1;
      }

      switch (transaction.statusFamily) {
        case DebugNetworkStatusFamily.twoXX:
          status2xx += 1;
          acc.status2xx += 1;
          break;
        case DebugNetworkStatusFamily.threeXX:
          status3xx += 1;
          acc.status3xx += 1;
          break;
        case DebugNetworkStatusFamily.fourXX:
          status4xx += 1;
          acc.status4xx += 1;
          break;
        case DebugNetworkStatusFamily.fiveXX:
          status5xx += 1;
          acc.status5xx += 1;
          break;
        case DebugNetworkStatusFamily.unknown:
          statusUnknown += 1;
          acc.statusUnknown += 1;
          break;
      }

      if (durationMs != null) {
        totalDurationMs += durationMs;
        durationSamples++;
        maxDurationMs = maxDurationMs == null || durationMs > maxDurationMs
            ? durationMs
            : maxDurationMs;
        minDurationMs = minDurationMs == null || durationMs < minDurationMs
            ? durationMs
            : minDurationMs;
        acc.durationTotalMs += durationMs;
        acc.durationSamples += 1;
        acc.maxDurationMs =
            acc.maxDurationMs == null || durationMs > acc.maxDurationMs!
                ? durationMs
                : acc.maxDurationMs;
        acc.minDurationMs =
            acc.minDurationMs == null || durationMs < acc.minDurationMs!
                ? durationMs
                : acc.minDurationMs;
      }

      if (durationMs != null && durationMs >= slowRequestThresholdMs) {
        slowRequests += 1;
        acc.slowCount += 1;
      }

      if (statusCode != null) {
        acc.lastStatusCode = statusCode;
      }
      final seenAt = transaction.startedAt;
      if (acc.lastSeenAt == null || seenAt.isAfter(acc.lastSeenAt!)) {
        acc.lastSeenAt = seenAt;
      }

      _addUnique(acc.relatedTraceIds, transaction.traceId);
      _addUnique(acc.relatedRequestIds, transaction.requestId);
      _addUnique(acc.backendRequestIds, transaction.backendRequestId);
      _addUnique(acc.backendCorrelationIds, transaction.backendCorrelationId);
      _addUnique(acc.backendTraceIds, transaction.backendTraceId);
    }

    final endpoints = endpointMap.values.map((acc) => acc.build()).toList();

    endpoints.sort((a, b) {
      final byFail = b.failedCount.compareTo(a.failedCount);
      if (byFail != 0) return byFail;
      final aSeen = a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bSeen = b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bSeen.compareTo(aSeen);
    });
    final topFailingEndpoints = endpoints
        .where((e) => e.failedCount > 0)
        .take(_maxTopEndpoints)
        .toList();

    final slowestEndpoints = [...endpoints]..sort((a, b) {
        final aMax = a.maxDurationMs ?? -1;
        final bMax = b.maxDurationMs ?? -1;
        final byMax = bMax.compareTo(aMax);
        if (byMax != 0) return byMax;
        final aAvg = a.averageDurationMs ?? -1;
        final bAvg = b.averageDurationMs ?? -1;
        return bAvg.compareTo(aAvg);
      });

    final mostCalledEndpoints = [...endpoints]..sort((a, b) {
        final byCount = b.totalCount.compareTo(a.totalCount);
        if (byCount != 0) return byCount;
        final aSeen = a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bSeen = b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bSeen.compareTo(aSeen);
      });

    return DebugNetworkSummary(
      generatedAt: DateTime.now(),
      slowRequestThresholdMs: slowRequestThresholdMs,
      totalRequests: totalRequests,
      pendingRequests: pendingRequests,
      completedRequests: completedRequests,
      failedRequests: failedRequests,
      slowRequests: slowRequests,
      averageDurationMs: durationSamples == 0
          ? 0
          : (totalDurationMs / durationSamples).round(),
      maxDurationMs: maxDurationMs,
      minDurationMs: minDurationMs,
      statusBreakdown: DebugNetworkStatusBreakdown(
        status2xx: status2xx,
        status3xx: status3xx,
        status4xx: status4xx,
        status5xx: status5xx,
        statusUnknown: statusUnknown,
      ),
      topFailingEndpoints: topFailingEndpoints,
      slowestEndpoints: slowestEndpoints.take(_maxTopEndpoints).toList(),
      mostCalledEndpoints: mostCalledEndpoints.take(_maxTopEndpoints).toList(),
    );
  }

  static void _addUnique(List<String> values, String? value) {
    if (value == null || value.trim().isEmpty) return;
    if (values.contains(value)) return;
    if (values.length >= _maxRelatedIds) return;
    values.add(value);
  }
}

class _EndpointAccumulator {
  final String method;
  final String path;
  int totalCount = 0;
  int completedCount = 0;
  int failedCount = 0;
  int slowCount = 0;
  int status2xx = 0;
  int status3xx = 0;
  int status4xx = 0;
  int status5xx = 0;
  int statusUnknown = 0;
  int durationTotalMs = 0;
  int durationSamples = 0;
  int? maxDurationMs;
  int? minDurationMs;
  int? lastStatusCode;
  DateTime? lastSeenAt;
  final List<String> relatedTraceIds = [];
  final List<String> relatedRequestIds = [];
  final List<String> backendRequestIds = [];
  final List<String> backendCorrelationIds = [];
  final List<String> backendTraceIds = [];

  _EndpointAccumulator({required this.method, required this.path});

  DebugNetworkEndpointStats build() {
    return DebugNetworkEndpointStats(
      method: method,
      path: path,
      totalCount: totalCount,
      completedCount: completedCount,
      failedCount: failedCount,
      slowCount: slowCount,
      status2xx: status2xx,
      status3xx: status3xx,
      status4xx: status4xx,
      status5xx: status5xx,
      statusUnknown: statusUnknown,
      averageDurationMs: durationSamples == 0
          ? null
          : (durationTotalMs / durationSamples).round(),
      maxDurationMs: maxDurationMs,
      minDurationMs: minDurationMs,
      lastStatusCode: lastStatusCode,
      lastSeenAt: lastSeenAt,
      relatedTraceIds: List.unmodifiable(relatedTraceIds),
      relatedRequestIds: List.unmodifiable(relatedRequestIds),
      backendRequestIds: List.unmodifiable(backendRequestIds),
      backendCorrelationIds: List.unmodifiable(backendCorrelationIds),
      backendTraceIds: List.unmodifiable(backendTraceIds),
    );
  }
}
