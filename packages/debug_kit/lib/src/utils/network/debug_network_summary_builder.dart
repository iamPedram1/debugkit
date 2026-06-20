import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_log_level.dart';
import '../../core/models/debug_network_endpoint_stats.dart';
import '../../core/models/debug_network_status_breakdown.dart';
import '../../core/models/debug_network_summary.dart';
import '../../core/models/debug_log_source.dart';

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

    for (final entry in logs) {
      if (!_isNetworkTransaction(entry)) continue;

      final method = _readMethod(entry);
      final path = _readPath(entry);
      if (method == null || path == null) continue;

      final key = '$method|$path';
      final acc = endpointMap.putIfAbsent(
        key,
        () => _EndpointAccumulator(method: method, path: path),
      );

      totalRequests += entry.repeatCount;
      acc.totalCount += entry.repeatCount;

      final phase = _readPhase(entry);
      final statusCode = _readStatusCode(entry);
      final durationMs = _readDurationMs(entry);
      final requestId = entry.requestId;
      final traceId = entry.traceId;
      final backendRequestId = _readMetadataValue(entry, const [
        'backendRequestId',
        'backend_request_id',
      ]);
      final backendCorrelationId = _readMetadataValue(entry, const [
        'backendCorrelationId',
        'backend_correlation_id',
      ]);
      final backendTraceId = _readMetadataValue(entry, const [
        'backendTraceId',
        'backend_trace_id',
      ]);

      if (_isPending(phase, statusCode, durationMs)) {
        pendingRequests += entry.repeatCount;
      } else if (_isFailed(entry, phase, statusCode)) {
        failedRequests += entry.repeatCount;
        acc.failedCount += entry.repeatCount;
      } else {
        completedRequests += entry.repeatCount;
        acc.completedCount += entry.repeatCount;
      }

      if (statusCode != null) {
        switch (_statusBucket(statusCode)) {
          case _StatusBucket.s2xx:
            status2xx += entry.repeatCount;
            acc.status2xx += entry.repeatCount;
            break;
          case _StatusBucket.s3xx:
            status3xx += entry.repeatCount;
            acc.status3xx += entry.repeatCount;
            break;
          case _StatusBucket.s4xx:
            status4xx += entry.repeatCount;
            acc.status4xx += entry.repeatCount;
            break;
          case _StatusBucket.s5xx:
            status5xx += entry.repeatCount;
            acc.status5xx += entry.repeatCount;
            break;
          case _StatusBucket.unknown:
            statusUnknown += entry.repeatCount;
            acc.statusUnknown += entry.repeatCount;
            break;
        }
      } else {
        statusUnknown += entry.repeatCount;
        acc.statusUnknown += entry.repeatCount;
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
        slowRequests += entry.repeatCount;
        acc.slowCount += entry.repeatCount;
      }

      if (statusCode != null) {
        acc.lastStatusCode = statusCode;
      }
      final seenAt = entry.lastSeenAt ?? entry.timestamp;
      if (acc.lastSeenAt == null || seenAt.isAfter(acc.lastSeenAt!)) {
        acc.lastSeenAt = seenAt;
      }

      _addUnique(acc.relatedTraceIds, traceId);
      _addUnique(acc.relatedRequestIds, requestId);
      _addUnique(acc.backendRequestIds, backendRequestId);
      _addUnique(acc.backendCorrelationIds, backendCorrelationId);
      _addUnique(acc.backendTraceIds, backendTraceId);
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

  static bool _isNetworkTransaction(DebugLogEntry entry) {
    final kind = _readMetadataValue(entry, const ['kind']);
    if (kind?.toLowerCase() == 'networktransaction') return true;
    if (entry.source == DebugLogSource.dio) return true;
    return _readMethod(entry) != null && _readPath(entry) != null;
  }

  static String? _readMethod(DebugLogEntry entry) {
    final method = _readMetadataValue(entry, const ['method']);
    if (method == null || method.trim().isEmpty) return null;
    return method.trim().toUpperCase();
  }

  static String? _readPath(DebugLogEntry entry) {
    final rawPath = _readMetadataValue(entry, const ['path']);
    if (rawPath == null || rawPath.trim().isEmpty) return null;
    final trimmed = rawPath.trim();
    try {
      final uri = Uri.parse(trimmed);
      final path = uri.path.isEmpty ? '/' : uri.path;
      return path.startsWith('/') ? path : '/$path';
    } catch (_) {
      final pathOnly = trimmed.split('?').first;
      if (pathOnly.isEmpty) return null;
      return pathOnly.startsWith('/') ? pathOnly : '/$pathOnly';
    }
  }

  static String? _readPhase(DebugLogEntry entry) {
    final phase = _readMetadataValue(entry, const ['phase']);
    if (phase == null || phase.trim().isEmpty) return null;
    return phase.trim().toLowerCase();
  }

  static int? _readStatusCode(DebugLogEntry entry) {
    final raw = _readMetadataValue(
        entry, const ['status', 'status_code', 'statusCode']);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  static int? _readDurationMs(DebugLogEntry entry) {
    final raw = _readMetadataValue(
        entry, const ['durationMs', 'duration_ms', 'duration']);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  static String? _readMetadataValue(DebugLogEntry entry, List<String> keys) {
    final metadata = entry.metadata;
    if (metadata == null || metadata.isEmpty) return null;
    for (final key in keys) {
      final value = metadata[key];
      if (value != null && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static bool _isPending(String? phase, int? statusCode, int? durationMs) {
    if (phase == 'pending') return true;
    return statusCode == null && durationMs == null;
  }

  static bool _isFailed(DebugLogEntry entry, String? phase, int? statusCode) {
    if (phase == 'failed') return true;
    if (phase == 'cancelled') return true;
    if (entry.level == DebugLogLevel.error) return true;
    if (statusCode != null && statusCode >= 400) return true;
    return false;
  }

  static _StatusBucket _statusBucket(int statusCode) {
    if (statusCode >= 200 && statusCode <= 299) return _StatusBucket.s2xx;
    if (statusCode >= 300 && statusCode <= 399) return _StatusBucket.s3xx;
    if (statusCode >= 400 && statusCode <= 499) return _StatusBucket.s4xx;
    if (statusCode >= 500 && statusCode <= 599) return _StatusBucket.s5xx;
    return _StatusBucket.unknown;
  }

  static void _addUnique(List<String> values, String? value) {
    if (value == null || value.trim().isEmpty) return;
    if (values.contains(value)) return;
    if (values.length >= _maxRelatedIds) return;
    values.add(value);
  }
}

enum _StatusBucket { s2xx, s3xx, s4xx, s5xx, unknown }

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
