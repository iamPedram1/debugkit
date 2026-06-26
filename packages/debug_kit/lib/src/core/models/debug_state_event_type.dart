/// The lifecycle/action type of a [DebugStateEvent].
enum DebugStateEventType {
  /// A provider or state node was added/initialized.
  added,

  /// A provider or state node changed value.
  updated,

  /// A provider or state node was disposed.
  disposed,

  /// A provider or state node reported an error.
  error;

  /// Human-friendly label shown in the State tab.
  String get label {
    return switch (this) {
      DebugStateEventType.added => 'Added',
      DebugStateEventType.updated => 'Updated',
      DebugStateEventType.disposed => 'Disposed',
      DebugStateEventType.error => 'Error',
    };
  }
}
