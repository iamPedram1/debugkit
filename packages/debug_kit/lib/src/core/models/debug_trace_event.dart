import 'debug_trace_event_type.dart';

/// A single event recorded within a [DebugTrace] timeline.
///
/// Events are immutable and contain only sanitized, serialization-friendly
/// data. No raw objects, route extras, request/response bodies, or provider
/// state objects are stored.
class DebugTraceEvent {
  /// Unique identifier for this event.
  final String id;

  /// The ID of the parent [DebugTrace].
  final String traceId;

  /// Human-readable name or message for this event.
  final String message;

  /// The category of this event.
  final DebugTraceEventType type;

  /// When this event was recorded.
  final DateTime timestamp;

  /// Optional duration in milliseconds (e.g. for network events).
  final int? durationMs;

  /// Optional sanitized metadata. Values must be plain strings.
  final Map<String, String>? metadata;

  /// Optional sanitized error string.
  final String? error;

  /// Optional request ID for correlating with Dio log entries.
  final String? requestId;

  const DebugTraceEvent({
    required this.id,
    required this.traceId,
    required this.message,
    required this.type,
    required this.timestamp,
    this.durationMs,
    this.metadata,
    this.error,
    this.requestId,
  });

  /// Returns the elapsed milliseconds since [traceStartedAt].
  int elapsedMs(DateTime traceStartedAt) =>
      timestamp.difference(traceStartedAt).inMilliseconds;
}
