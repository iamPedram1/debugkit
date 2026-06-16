/// The lifecycle status of a [DebugTrace].
enum DebugTraceStatus {
  /// The trace is currently running.
  running,

  /// The trace completed successfully.
  success,

  /// The trace ended with an error.
  failed,

  /// The trace was explicitly cancelled.
  cancelled;

  String get label {
    return switch (this) {
      DebugTraceStatus.running => 'RUNNING',
      DebugTraceStatus.success => 'SUCCESS',
      DebugTraceStatus.failed => 'FAILED',
      DebugTraceStatus.cancelled => 'CANCELLED',
    };
  }
}
