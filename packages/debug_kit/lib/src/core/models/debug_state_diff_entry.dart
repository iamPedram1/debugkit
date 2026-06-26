import 'debug_state_diff_type.dart';

/// A single structured field-level change in a state event.
class DebugStateDiffEntry {
  /// Path to the changed value, e.g. `profile.metadata.status`.
  final String path;

  /// The kind of change that occurred.
  final DebugStateDiffType type;

  /// Sanitized short preview of the previous value.
  final String? previousValuePreview;

  /// Sanitized short preview of the next value.
  final String? nextValuePreview;

  /// Creates a [DebugStateDiffEntry].
  const DebugStateDiffEntry({
    required this.path,
    required this.type,
    this.previousValuePreview,
    this.nextValuePreview,
  });

  /// Returns a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'type': type.name,
      'previousValuePreview': previousValuePreview,
      'nextValuePreview': nextValuePreview,
    };
  }

  /// Creates a [DebugStateDiffEntry] from a JSON-like map.
  factory DebugStateDiffEntry.fromJson(Map<String, dynamic> json) {
    return DebugStateDiffEntry(
      path: json['path'] as String,
      type: DebugStateDiffType.values.byName(json['type'] as String),
      previousValuePreview: json['previousValuePreview'] as String?,
      nextValuePreview: json['nextValuePreview'] as String?,
    );
  }

  /// Returns a copy of this entry with selected fields replaced.
  DebugStateDiffEntry copyWith({
    String? path,
    DebugStateDiffType? type,
    String? previousValuePreview,
    String? nextValuePreview,
  }) {
    return DebugStateDiffEntry(
      path: path ?? this.path,
      type: type ?? this.type,
      previousValuePreview: previousValuePreview ?? this.previousValuePreview,
      nextValuePreview: nextValuePreview ?? this.nextValuePreview,
    );
  }
}
