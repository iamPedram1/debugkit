/// The type of a structured state diff entry.
enum DebugStateDiffType {
  /// The field or key was added.
  added,

  /// The field or key was removed.
  removed,

  /// The field or value changed.
  changed,

  /// The field or value did not change.
  unchanged;

  /// Human-friendly label shown in the State tab.
  String get label {
    return switch (this) {
      DebugStateDiffType.added => 'Added',
      DebugStateDiffType.removed => 'Removed',
      DebugStateDiffType.changed => 'Changed',
      DebugStateDiffType.unchanged => 'Unchanged',
    };
  }
}
