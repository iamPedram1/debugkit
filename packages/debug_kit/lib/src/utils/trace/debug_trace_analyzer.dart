import '../../core/models/debug_trace.dart';
import '../../core/models/debug_trace_event_type.dart';
import '../../core/models/debug_trace_status.dart';

/// Lightweight, stateless health analyzer for [DebugTrace] instances.
///
/// All methods are pure functions — no side effects, no mutable state.
/// Call [analyze] to get a list of human-readable warning strings for a trace,
/// or [hasWarnings] for a quick boolean check.
///
/// Used by the trace detail screen and the [DebugTraceExportFormatter] to
/// surface actionable observations alongside trace data.
class DebugTraceAnalyzer {
  const DebugTraceAnalyzer._();

  /// Duration above which a completed trace is flagged as slow.
  ///
  /// Default: 3 seconds. Override per-call via the [analyze] `slowThreshold`
  /// parameter, or globally via [DebugKitConfig.slowTraceThreshold].
  static const Duration defaultSlowThreshold = Duration(seconds: 3);

  /// Number of events at or above which a trace is considered to have an
  /// unusually high event count.
  ///
  /// Default: 100 events.
  static const int defaultMaxEventWarningCount = 100;

  /// Running duration above which an in-progress trace is considered stale
  /// (possibly leaked / never closed).
  ///
  /// Default: 2 minutes.
  static const Duration defaultStaleThreshold = Duration(minutes: 2);

  /// Analyzes [trace] and returns a list of human-readable warning strings.
  ///
  /// Returns an empty list when the trace is healthy. The following conditions
  /// produce warnings:
  ///
  /// | Condition | Warning example |
  /// |-----------|-----------------|
  /// | Status is [DebugTraceStatus.failed] | `'trace failed: Auth failed'` |
  /// | Status is [DebugTraceStatus.cancelled] | `'trace was cancelled'` |
  /// | Duration > [slowThreshold] | `'slow trace: 4200ms (threshold: 3000ms)'` |
  /// | Still running > [staleThreshold] | `'trace still running after 150s — possible leak'` |
  /// | Event count ≥ [maxEventWarningCount] | `'high event count: 103 events (threshold: 100)'` |
  /// | ≥ 1 failed network events | `'2 failed network request(s) inside trace'` |
  /// | > 1 error events | `'3 error events recorded in trace'` |
  /// | ≥ 3 error events with repeated messages | `'repeated errors detected inside trace'` |
  ///
  /// Parameters:
  /// - [slowThreshold]: overrides [defaultSlowThreshold] for this call.
  /// - [maxEventWarningCount]: overrides [defaultMaxEventWarningCount].
  /// - [staleThreshold]: overrides [defaultStaleThreshold].
  static List<String> analyze(
    DebugTrace trace, {
    Duration slowThreshold = defaultSlowThreshold,
    int maxEventWarningCount = defaultMaxEventWarningCount,
    Duration staleThreshold = defaultStaleThreshold,
  }) {
    final warnings = <String>[];

    // --- Status-based ---
    if (trace.status == DebugTraceStatus.failed) {
      warnings.add('trace failed: ${trace.errorSummary ?? 'unknown error'}');
    }

    if (trace.status == DebugTraceStatus.cancelled) {
      warnings.add('trace was cancelled');
    }

    // --- Duration-based ---
    final duration = trace.duration;
    if (duration != null && duration > slowThreshold) {
      warnings.add(
        'slow trace: ${duration.inMilliseconds}ms '
        '(threshold: ${slowThreshold.inMilliseconds}ms)',
      );
    }

    // --- Stale running trace ---
    if (trace.isRunning) {
      final elapsed = DateTime.now().difference(trace.startedAt);
      if (elapsed > staleThreshold) {
        warnings.add(
          'trace still running after ${elapsed.inSeconds}s — possible leak',
        );
      }
    }

    // --- High event count ---
    if (trace.events.length >= maxEventWarningCount) {
      warnings.add(
        'high event count: ${trace.events.length} events '
        '(threshold: $maxEventWarningCount)',
      );
    }

    // --- Failed network requests inside the trace ---
    final failedNetworkEvents = trace.events
        .where((e) => e.type == DebugTraceEventType.network && e.error != null)
        .toList();
    if (failedNetworkEvents.isNotEmpty) {
      warnings.add(
        '${failedNetworkEvents.length} failed network request(s) inside trace',
      );
    }

    // --- Multiple error events ---
    final errorEvents =
        trace.events.where((e) => e.type == DebugTraceEventType.error).toList();
    if (errorEvents.length > 1) {
      warnings.add(
        '${errorEvents.length} error events recorded in trace',
      );
    }

    // --- Repeated identical error messages ---
    if (errorEvents.length >= 3) {
      final messages = errorEvents.map((e) => e.message).toList();
      final unique = messages.toSet();
      if (unique.length < messages.length) {
        warnings.add('repeated errors detected inside trace');
      }
    }

    return warnings;
  }

  /// Returns `true` when [analyze] would produce at least one warning for
  /// [trace].
  ///
  /// - [slowThreshold]: forwarded to [analyze].
  static bool hasWarnings(
    DebugTrace trace, {
    Duration slowThreshold = defaultSlowThreshold,
  }) {
    return analyze(trace, slowThreshold: slowThreshold).isNotEmpty;
  }
}
