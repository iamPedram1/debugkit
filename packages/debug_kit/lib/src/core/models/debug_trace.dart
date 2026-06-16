import 'debug_trace_event.dart';
import 'debug_trace_status.dart';

/// A named trace that groups a sequence of [DebugTraceEvent]s into a timeline.
///
/// Traces are immutable snapshots. The [DebugTraceStore] manages mutable
/// state and produces [DebugTrace] instances via [copyWith].
class DebugTrace {
  /// Unique identifier for this trace.
  final String id;

  /// Human-readable name (e.g. `'login_flow'`).
  final String name;

  /// Current lifecycle status.
  final DebugTraceStatus status;

  /// When the trace was started.
  final DateTime startedAt;

  /// When the trace ended (null while still running).
  final DateTime? endedAt;

  /// Ordered list of events recorded during this trace.
  final List<DebugTraceEvent> events;

  /// Optional sanitized metadata attached at trace start.
  final Map<String, String>? metadata;

  /// Sanitized error summary if the trace failed.
  final String? errorSummary;

  /// Optional parent trace ID for nested traces.
  final String? parentTraceId;

  const DebugTrace({
    required this.id,
    required this.name,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.events = const [],
    this.metadata,
    this.errorSummary,
    this.parentTraceId,
  });

  /// Duration of the trace. Returns null while still running.
  Duration? get duration {
    if (endedAt == null) return null;
    return endedAt!.difference(startedAt);
  }

  /// Duration in milliseconds. Returns null while still running.
  int? get durationMs => duration?.inMilliseconds;

  /// Whether the trace is still active.
  bool get isRunning => status == DebugTraceStatus.running;

  DebugTrace copyWith({
    DebugTraceStatus? status,
    DateTime? endedAt,
    List<DebugTraceEvent>? events,
    String? errorSummary,
  }) {
    return DebugTrace(
      id: id,
      name: name,
      status: status ?? this.status,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      events: events ?? this.events,
      metadata: metadata,
      errorSummary: errorSummary ?? this.errorSummary,
      parentTraceId: parentTraceId,
    );
  }
}
