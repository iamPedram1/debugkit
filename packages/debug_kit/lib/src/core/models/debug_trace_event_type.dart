/// The type of a [DebugTraceEvent].
enum DebugTraceEventType {
  /// A named step within the trace flow.
  step,

  /// A log message emitted inside the trace.
  log,

  /// A network request or response event.
  network,

  /// A navigation event.
  navigation,

  /// A state change event (e.g. provider update/failure).
  state,

  /// An error or exception event.
  error,

  /// A custom event type for adapter-specific use.
  custom;

  String get label {
    return switch (this) {
      DebugTraceEventType.step => 'STEP',
      DebugTraceEventType.log => 'LOG',
      DebugTraceEventType.network => 'NET',
      DebugTraceEventType.navigation => 'NAV',
      DebugTraceEventType.state => 'STATE',
      DebugTraceEventType.error => 'ERR',
      DebugTraceEventType.custom => 'CUSTOM',
    };
  }
}
