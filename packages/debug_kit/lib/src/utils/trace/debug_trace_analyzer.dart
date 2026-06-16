import '../../core/models/debug_trace.dart';
import '../../core/models/debug_trace_event_type.dart';
import '../../core/models/debug_trace_status.dart';

/// A lightweight, stateless analyzer that produces human-readable health
/// warnings for a [DebugTrace].
///
/// All methods are pure functions — no side effects, no state.
class DebugTraceAnalyzer {
  const DebugTraceAnalyzer._();

  /// Default threshold above which a trace is considered slow.
  static const Duration defaultSlowThreshold = Duration(seconds: 3);

  /// Default threshold above which a trace is considered to have too many events.
  static const int defaultMaxEventWarningCount = 100;

  /// Default threshold above which a running trace is considered stale.
  static const Duration defaultStaleThreshold = Duration(minutes: 2);

  /// Returns a list of human-readable warning strings for [trace].
  ///
  /// Returns an empty list if the trace is healthy.
  static List<String> analyze(
    DebugTrace trace, {
    Duration slowThreshold = defaultSlowThreshold,
    int maxEventWarningCount = defaultMaxEventWarningCount,
    Duration staleThreshold = defaultStaleThreshold,
  }) {
    final warnings = <String>[];

    // Status-based warnings
    if (trace.status == DebugTraceStatus.failed) {
      warnings.add('trace failed: ${trace.errorSummary ?? 'unknown error'}');
    }

    if (trace.status == DebugTraceStatus.cancelled) {
      warnings.add('trace was cancelled');
    }

    // Duration-based warnings
    final duration = trace.duration;
    if (duration != null && duration > slowThreshold) {
      warnings.add(
          'slow trace: ${duration.inMilliseconds}ms (threshold: ${slowThreshold.inMilliseconds}ms)');
    }

    // Stale running trace
    if (trace.isRunning) {
      final elapsed = DateTime.now().difference(trace.startedAt);
      if (elapsed > staleThreshold) {
        warnings.add(
            'trace still running after ${elapsed.inSeconds}s — possible leak');
      }
    }

    // Event count warning
    if (trace.events.length >= maxEventWarningCount) {
      warnings.add(
          'high event count: ${trace.events.length} events (threshold: $maxEventWarningCount)');
    }

    // Network failure events
    final failedNetworkEvents = trace.events
        .where((e) => e.type == DebugTraceEventType.network && e.error != null)
        .toList();
    if (failedNetworkEvents.isNotEmpty) {
      warnings.add(
          '${failedNetworkEvents.length} failed network request(s) inside trace');
    }

    // Error events
    final errorEvents =
        trace.events.where((e) => e.type == DebugTraceEventType.error).toList();
    if (errorEvents.length > 1) {
      warnings.add('${errorEvents.length} error events recorded in trace');
    }

    // Repeated identical error messages
    if (errorEvents.length >= 3) {
      final messages = errorEvents.map((e) => e.message).toList();
      final unique = messages.toSet();
      if (unique.length < messages.length) {
        warnings.add('repeated errors detected inside trace');
      }
    }

    return warnings;
  }

  /// Returns true if the trace has any health warnings.
  static bool hasWarnings(
    DebugTrace trace, {
    Duration slowThreshold = defaultSlowThreshold,
  }) {
    return analyze(trace, slowThreshold: slowThreshold).isNotEmpty;
  }
}
