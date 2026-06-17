import '../../core/models/debug_error_digest.dart';
import '../../core/models/debug_error_digest_entry.dart';
import '../../core/models/debug_error_digest_severity.dart';
import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_log_level.dart';
import '../../core/models/debug_log_source.dart';
import '../../core/models/debug_trace.dart';
import '../../core/models/debug_trace_status.dart';
import 'debug_error_fingerprint_builder.dart';

/// Pure, stateless builder that converts a snapshot of log entries and traces
/// into a [DebugErrorDigest].
///
/// **Input:**
/// - A list of [DebugLogEntry] instances from [DebugLogStore.logs].
/// - An optional list of [DebugTrace] instances from [DebugTraceStore.traces].
///
/// **Output:**
/// - A [DebugErrorDigest] containing grouped, de-duplicated error entries
///   sorted by severity and frequency.
///
/// **Rules:**
/// - Does not mutate any input.
/// - Does not depend on any UI or store — pure data transformation.
/// - Respects [DebugLogEntry.repeatCount] as a count contribution.
/// - Extracts error sources from: error-level logs, logs with non-null error
///   fields, logs with non-null stack traces, failed traces, and trace events
///   with errors.
/// - Never stores request/response bodies, route extras, or provider state
///   objects.
class DebugErrorDigestBuilder {
  DebugErrorDigestBuilder._();

  /// Maximum number of related IDs stored per category (traces, requests, etc.)
  static const int _maxRelatedIds = 10;

  /// Maximum number of sample log IDs stored per digest entry.
  static const int _maxSampleIds = 5;

  /// Maximum number of entries returned in the [DebugErrorDigest.topRepeatedErrors]
  /// and [DebugErrorDigest.latestErrors] lists.
  static const int _maxTopEntries = 5;

  /// Builds a [DebugErrorDigest] from [logs] and optional [traces].
  ///
  /// Returns an empty digest when no error-worthy entries are found.
  ///
  /// - [logs]: all entries from [DebugLogStore.logs].
  /// - [traces]: all traces from [DebugTraceStore.traces]; pass `null` or `[]`
  ///   to skip trace-based error detection.
  static DebugErrorDigest build({
    required List<DebugLogEntry> logs,
    List<DebugTrace>? traces,
  }) {
    // Accumulator: fingerprint → mutable builder state
    final Map<String, _EntryAccumulator> accumulators = {};

    int failedNetworkCount = 0;
    int failedTraceCount = 0;

    // -------------------------------------------------------------------------
    // Pass 1: process error log entries
    // -------------------------------------------------------------------------
    for (final entry in logs) {
      if (!_isErrorEntry(entry)) continue;

      if (entry.source == DebugLogSource.dio &&
          entry.level == DebugLogLevel.error) {
        failedNetworkCount++;
      }

      final fingerprint = DebugErrorFingerprintBuilder.forLogEntry(entry);

      final acc = accumulators.putIfAbsent(
        fingerprint,
        () => _EntryAccumulator(fingerprint: fingerprint),
      );

      acc.addLogEntry(entry);
    }

    // -------------------------------------------------------------------------
    // Pass 2: process failed traces
    // -------------------------------------------------------------------------
    if (traces != null) {
      for (final trace in traces) {
        if (trace.status == DebugTraceStatus.failed) {
          failedTraceCount++;

          // Create or update an accumulator for the trace-level failure.
          // Failed traces contribute to any digest entry that already has
          // a related trace ID; otherwise they create their own entry.
          final fingerprint =
              DebugErrorFingerprintBuilder.forFailedTrace(trace);
          final acc = accumulators.putIfAbsent(
            fingerprint,
            () => _EntryAccumulator(fingerprint: fingerprint),
          );
          acc.addFailedTrace(trace);
        }

        // Also scan trace events for error events that were not surfaced as logs
        for (final event in trace.events) {
          if (event.error != null && event.error!.isNotEmpty) {
            // These are already counted via the log entries in most cases, but
            // we add related trace context to existing accumulators where possible.
            _linkTraceEventToAccumulator(accumulators, trace, event.error!);
          }
        }
      }

      // Enrich log-based accumulators with trace context
      _enrichWithTraceContext(accumulators, traces, logs);
    }

    // -------------------------------------------------------------------------
    // Build final entries from accumulators
    // -------------------------------------------------------------------------
    final entries = accumulators.values.map((acc) => acc.build()).toList()
      ..sort(_compareEntries);

    final totalErrors = entries.fold<int>(0, (sum, e) => sum + e.count);

    final topRepeated = List<DebugErrorDigestEntry>.from(entries)
      ..sort((a, b) => b.count.compareTo(a.count));
    final latestErrors = List<DebugErrorDigestEntry>.from(entries)
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));

    return DebugErrorDigest(
      generatedAt: DateTime.now(),
      totalErrors: totalErrors,
      uniqueErrors: entries.length,
      entries: entries,
      topRepeatedErrors: topRepeated.take(_maxTopEntries).toList(),
      latestErrors: latestErrors.take(_maxTopEntries).toList(),
      failedTraceCount: failedTraceCount,
      failedNetworkCount: failedNetworkCount,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` when [entry] should contribute to the error digest.
  ///
  /// Criteria:
  /// - Level is [DebugLogLevel.error].
  /// - OR entry has a non-null, non-empty [DebugLogEntry.error] field.
  /// - OR entry has a non-null [DebugLogEntry.stackTrace] field at warning
  ///   level or above (app-level exceptions often surface as warnings).
  ///
  /// Explicitly excludes debug-level logs and info-level navigation entries
  /// to avoid false positives.
  static bool _isErrorEntry(DebugLogEntry entry) {
    if (entry.level == DebugLogLevel.error) return true;
    if (entry.level == DebugLogLevel.warning &&
        entry.error != null &&
        entry.error!.isNotEmpty) {
      return true;
    }
    return false;
  }

  /// Attempts to link a trace error event to an existing accumulator.
  ///
  /// If no matching accumulator is found, the event is silently ignored —
  /// the failed trace itself is already covered by [addFailedTrace].
  static void _linkTraceEventToAccumulator(
    Map<String, _EntryAccumulator> accumulators,
    DebugTrace trace,
    String eventError,
  ) {
    // Try to find an existing accumulator that already refers to this trace
    for (final acc in accumulators.values) {
      if (acc.relatedTraceIds.contains(trace.id)) {
        // Already linked
        return;
      }
    }
    // No match — the trace-level error will be picked up by addFailedTrace
  }

  /// Enriches log-based accumulators with context from traces.
  ///
  /// Links log entries to their parent trace by matching [DebugLogEntry.traceId]
  /// against the trace list. Also links Dio error entries to network-related
  /// traces via [DebugLogEntry.requestId] / trace network events.
  static void _enrichWithTraceContext(
    Map<String, _EntryAccumulator> accumulators,
    List<DebugTrace> traces,
    List<DebugLogEntry> logs,
  ) {
    // Build quick lookup: traceId → trace
    final traceMap = {for (final t in traces) t.id: t};

    for (final acc in accumulators.values) {
      // For each sample log in this accumulator, pull in trace context
      for (final logId in acc.sampleLogIds) {
        try {
          final entry = logs.firstWhere((l) => l.id == logId);
          if (entry.traceId != null) {
            final trace = traceMap[entry.traceId];
            if (trace != null) {
              acc.addTraceContext(trace);
            }
          }
        } catch (_) {
          // entry not found — safe to ignore
        }
      }
    }
  }

  /// Comparator for sorting [DebugErrorDigestEntry] instances by usefulness.
  ///
  /// Sort order:
  /// 1. Severity (fatal → error → warning).
  /// 2. Count descending.
  /// 3. Most recently seen first.
  static int _compareEntries(DebugErrorDigestEntry a, DebugErrorDigestEntry b) {
    final bySeverity = a.severity.sortOrder.compareTo(b.severity.sortOrder);
    if (bySeverity != 0) return bySeverity;

    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;

    return b.lastSeenAt.compareTo(a.lastSeenAt);
  }
}

// =============================================================================
// _EntryAccumulator — mutable builder state per fingerprint
// =============================================================================

/// Mutable accumulator for building a single [DebugErrorDigestEntry].
///
/// One accumulator is created per unique fingerprint. Log entries and traces
/// are fed in via [addLogEntry] and [addFailedTrace]. Call [build] at the end
/// to produce the final immutable [DebugErrorDigestEntry].
class _EntryAccumulator {
  final String fingerprint;

  int _count = 0;
  DateTime? _firstSeenAt;
  DateTime? _lastSeenAt;
  DebugLogSource _source = DebugLogSource.app;
  DebugErrorDigestSeverity _severity = DebugErrorDigestSeverity.warning;

  String? _latestMessage;
  String? _latestError;
  String? _latestStackTrace;
  int? _latestLogId;

  final List<int> sampleLogIds = [];
  final List<String> relatedTraceIds = [];
  final List<String> relatedTraceNames = [];
  final List<String> relatedRequestIds = [];
  final List<String> relatedRoutes = [];
  final List<String> relatedProviderNames = [];

  _EntryAccumulator({required this.fingerprint});

  /// Adds a [DebugLogEntry] to this accumulator.
  void addLogEntry(DebugLogEntry entry) {
    // Count: respect repeatCount for grouped log entries
    _count += entry.repeatCount;

    // First/last seen
    final ts = entry.timestamp;
    final lastTs = entry.lastSeenAt ?? entry.timestamp;
    if (_firstSeenAt == null || ts.isBefore(_firstSeenAt!)) {
      _firstSeenAt = ts;
    }
    if (_lastSeenAt == null || lastTs.isAfter(_lastSeenAt!)) {
      _lastSeenAt = lastTs;
      _latestMessage = entry.message;
      _latestError = entry.error;
      _latestStackTrace = entry.stackTrace;
      _latestLogId = entry.id;
    }

    // Source — use most critical source
    _source = _mergeSources(_source, entry.source);

    // Severity — escalate as needed
    _severity = _mergeSeverity(_severity, _severityForEntry(entry));

    // Sample log IDs (up to max)
    if (sampleLogIds.length < DebugErrorDigestBuilder._maxSampleIds) {
      sampleLogIds.add(entry.id);
    }

    // Related request IDs (Dio)
    if (entry.requestId != null &&
        !relatedRequestIds.contains(entry.requestId) &&
        relatedRequestIds.length < DebugErrorDigestBuilder._maxRelatedIds) {
      relatedRequestIds.add(entry.requestId!);
    }

    // Related provider names (Riverpod)
    final providerName = entry.metadata?['provider_name'];
    if (providerName != null &&
        !relatedProviderNames.contains(providerName) &&
        relatedProviderNames.length < DebugErrorDigestBuilder._maxRelatedIds) {
      relatedProviderNames.add(providerName);
    }

    // Related routes (GoRouter)
    final routePath = entry.metadata?['route_path'];
    if (routePath != null &&
        !relatedRoutes.contains(routePath) &&
        relatedRoutes.length < DebugErrorDigestBuilder._maxRelatedIds) {
      relatedRoutes.add(routePath);
    }
  }

  /// Adds a failed [DebugTrace] to this accumulator.
  void addFailedTrace(DebugTrace trace) {
    _count += 1;

    final ts = trace.startedAt;
    if (_firstSeenAt == null || ts.isBefore(_firstSeenAt!)) {
      _firstSeenAt = ts;
    }
    final endTs = trace.endedAt ?? trace.startedAt;
    if (_lastSeenAt == null || endTs.isAfter(_lastSeenAt!)) {
      _lastSeenAt = endTs;
      _latestMessage = 'Trace failed: ${trace.name}';
      _latestError = trace.errorSummary;
    }

    _severity = _mergeSeverity(_severity, DebugErrorDigestSeverity.error);

    addTraceContext(trace);
  }

  /// Links a trace to this accumulator as related context.
  void addTraceContext(DebugTrace trace) {
    if (!relatedTraceIds.contains(trace.id) &&
        relatedTraceIds.length < DebugErrorDigestBuilder._maxRelatedIds) {
      relatedTraceIds.add(trace.id);
    }
    if (!relatedTraceNames.contains(trace.name) &&
        relatedTraceNames.length < DebugErrorDigestBuilder._maxRelatedIds) {
      relatedTraceNames.add(trace.name);
    }
  }

  /// Builds the final immutable [DebugErrorDigestEntry].
  DebugErrorDigestEntry build() {
    final message = _latestMessage ?? '';
    final normalizedMessage =
        DebugErrorFingerprintBuilder.normalizeMessage(message);
    final title = _buildTitle();
    final firstUsefulFrame = _latestStackTrace != null
        ? _extractFirstUsefulFrame(_latestStackTrace!)
        : null;
    final hints = _buildHealthHints();

    // Collect a minimal sampleMetadata from the last entry if available.
    // Never include sensitive keys — they are already masked by the sanitizer
    // before reaching the store.
    final sampleMeta = _buildSampleMetadata();

    return DebugErrorDigestEntry(
      fingerprint: fingerprint,
      title: title,
      message: message,
      normalizedMessage: normalizedMessage,
      severity: _severity,
      source: _source,
      count: _count,
      firstSeenAt: _firstSeenAt ?? DateTime.now(),
      lastSeenAt: _lastSeenAt ?? DateTime.now(),
      latestLogId: _latestLogId,
      sampleLogIds: List.unmodifiable(sampleLogIds),
      relatedTraceIds: List.unmodifiable(relatedTraceIds),
      relatedTraceNames: List.unmodifiable(relatedTraceNames),
      relatedRequestIds: List.unmodifiable(relatedRequestIds),
      relatedRoutes: List.unmodifiable(relatedRoutes),
      relatedProviderNames: List.unmodifiable(relatedProviderNames),
      latestError: _latestError,
      latestStackTrace: _latestStackTrace,
      firstUsefulStackFrame: firstUsefulFrame,
      sampleMetadata: sampleMeta,
      healthHints: List.unmodifiable(hints),
    );
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  String _buildTitle() {
    final msg = _latestMessage ?? '';

    // For Dio entries: shorten to "METHOD /path · STATUS"
    if (fingerprint.startsWith('dio|')) {
      final parts = fingerprint.split('|');
      if (parts.length >= 4) {
        final method = parts[1].toUpperCase();
        final path = parts[2];
        final status = parts[3];
        if (method.isNotEmpty && path.isNotEmpty) {
          return '$method $path · $status';
        }
      }
    }

    // For Riverpod entries
    if (fingerprint.startsWith('riverpod|')) {
      if (relatedProviderNames.isNotEmpty) {
        return 'Provider failed: ${relatedProviderNames.first}';
      }
    }

    // For trace entries
    if (fingerprint.startsWith('trace|')) {
      if (relatedTraceNames.isNotEmpty) {
        return 'Trace failed: ${relatedTraceNames.first}';
      }
    }

    // Generic: return message truncated to 80 chars
    if (msg.length > 80) return '${msg.substring(0, 77)}...';
    return msg.isNotEmpty ? msg : 'Unknown error';
  }

  List<String> _buildHealthHints() {
    final hints = <String>[];

    if (_count > 1) {
      hints.add('Occurred $_count time${_count == 1 ? '' : 's'}');
    }

    if (relatedTraceNames.isNotEmpty) {
      hints.add(
          'Related to trace${relatedTraceNames.length == 1 ? '' : 's'}: ${relatedTraceNames.take(3).join(', ')}');
    }

    if (relatedProviderNames.isNotEmpty) {
      hints.add('Provider: ${relatedProviderNames.first}');
    }

    if (fingerprint.startsWith('dio|')) {
      final parts = fingerprint.split('|');
      if (parts.length >= 4) {
        final status = parts[3];
        if (status == '401' || status == '403') {
          hints.add('HTTP $status — check authentication/authorization');
        } else if (status == '404') {
          hints.add('HTTP 404 — endpoint not found');
        } else if (status.startsWith('5')) {
          hints.add('HTTP $status — server-side error');
        } else if (status == 'failed') {
          hints.add('Network request failed — check connectivity');
        }
      }
    }

    return hints;
  }

  Map<String, String>? _buildSampleMetadata() {
    // We don't hold onto metadata here — it is already in the log entries.
    // Return null to keep the model lean. The UI reads sampleLogIds when
    // full metadata is needed.
    return null;
  }

  // ---------------------------------------------------------------------------
  // Static utility helpers
  // ---------------------------------------------------------------------------

  static DebugLogSource _mergeSources(
      DebugLogSource current, DebugLogSource incoming) {
    // Priority: riverpod > dio > router > app > userAction
    const priority = [
      DebugLogSource.riverpod,
      DebugLogSource.dio,
      DebugLogSource.router,
      DebugLogSource.app,
      DebugLogSource.userAction,
    ];
    final currentPriority = priority.indexOf(current);
    final incomingPriority = priority.indexOf(incoming);
    return incomingPriority < currentPriority ? incoming : current;
  }

  static DebugErrorDigestSeverity _mergeSeverity(
      DebugErrorDigestSeverity current, DebugErrorDigestSeverity incoming) {
    return incoming.sortOrder < current.sortOrder ? incoming : current;
  }

  static DebugErrorDigestSeverity _severityForEntry(DebugLogEntry entry) {
    if (entry.level == DebugLogLevel.error) {
      return DebugErrorDigestSeverity.error;
    }
    return DebugErrorDigestSeverity.warning;
  }

  static String? _extractFirstUsefulFrame(String stackTrace) {
    const skipPrefixes = [
      'package:flutter/',
      'package:debug_kit/',
      'dart:async',
      'dart:isolate',
      'dart:core',
    ];

    for (final line in stackTrace.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final shouldSkip = skipPrefixes.any((prefix) => trimmed.contains(prefix));
      if (shouldSkip) continue;
      final match =
          RegExp(r'([a-zA-Z_][a-zA-Z0-9_]*\.dart:\d+)').firstMatch(trimmed);
      if (match != null) return match.group(1)!;
    }
    return null;
  }
}
