import 'debug_state_diff_entry.dart';
import 'debug_state_event_type.dart';

/// A single sanitized state-management event stored by DebugKit.
///
/// The model is intentionally state-management agnostic. Riverpod, Bloc,
/// Provider, GetX, or future adapters can all map their lifecycle events into
/// this structure without exposing framework-specific types to core.
class DebugStateEvent {
  /// Unique identifier for this event.
  final String id;

  /// When the event was recorded.
  final DateTime timestamp;

  /// Adapter or source name, e.g. `riverpod`, `bloc`, or `provider`.
  final String source;

  /// Human-friendly state node name, e.g. `authProvider`.
  final String name;

  /// Optional framework or node type, e.g. `FutureProvider`, `Cubit`.
  final String? type;

  /// Lifecycle/action type.
  final DebugStateEventType eventType;

  /// Sanitized short preview of the previous value.
  final String? previousValuePreview;

  /// Sanitized short preview of the next value.
  final String? nextValuePreview;

  /// Optional compact diff or summary.
  final String? diffPreview;

  /// Structured field-level changes, when available.
  final List<DebugStateDiffEntry> changes;

  /// Sanitized error message, if this event represents a failure.
  final String? error;

  /// Sanitized stack trace, trimmed to a bounded number of lines.
  final String? stackTrace;

  /// Optional sanitized metadata.
  final Map<String, String>? metadata;

  /// Creates a [DebugStateEvent].
  const DebugStateEvent({
    required this.id,
    required this.timestamp,
    required this.source,
    required this.name,
    required this.eventType,
    this.type,
    this.previousValuePreview,
    this.nextValuePreview,
    this.diffPreview,
    this.changes = const [],
    this.error,
    this.stackTrace,
    this.metadata,
  });

  /// Returns a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'name': name,
      'type': type,
      'eventType': eventType.name,
      'previousValuePreview': previousValuePreview,
      'nextValuePreview': nextValuePreview,
      'diffPreview': diffPreview,
      'changes': changes.map((entry) => entry.toJson()).toList(),
      'error': error,
      'stackTrace': stackTrace,
      'metadata': metadata,
    };
  }

  /// Creates a [DebugStateEvent] from a JSON-like map.
  factory DebugStateEvent.fromJson(Map<String, dynamic> json) {
    return DebugStateEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      source: json['source'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
      eventType: DebugStateEventType.values.byName(json['eventType'] as String),
      previousValuePreview: json['previousValuePreview'] as String?,
      nextValuePreview: json['nextValuePreview'] as String?,
      diffPreview: json['diffPreview'] as String?,
      changes: (json['changes'] as List<dynamic>? ?? const [])
          .map((entry) => DebugStateDiffEntry.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ))
          .toList(),
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
      metadata: (json['metadata'] as Map?)?.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }

  /// Returns a copy of this event with selected fields replaced.
  DebugStateEvent copyWith({
    String? id,
    DateTime? timestamp,
    String? source,
    String? name,
    String? type,
    DebugStateEventType? eventType,
    String? previousValuePreview,
    String? nextValuePreview,
    String? diffPreview,
    List<DebugStateDiffEntry>? changes,
    String? error,
    String? stackTrace,
    Map<String, String>? metadata,
  }) {
    return DebugStateEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      name: name ?? this.name,
      type: type ?? this.type,
      eventType: eventType ?? this.eventType,
      previousValuePreview: previousValuePreview ?? this.previousValuePreview,
      nextValuePreview: nextValuePreview ?? this.nextValuePreview,
      diffPreview: diffPreview ?? this.diffPreview,
      changes: changes ?? this.changes,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      metadata: metadata ?? this.metadata,
    );
  }
}
