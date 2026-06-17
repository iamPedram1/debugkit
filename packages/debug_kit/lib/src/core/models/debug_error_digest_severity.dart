/// Severity classification for a [DebugErrorDigestEntry].
///
/// Derived from the [DebugLogLevel] and source of the contributing log entries,
/// and from the status of related failed traces.
enum DebugErrorDigestSeverity {
  /// An unrecoverable or critical error — e.g. a fatal exception or a
  /// failed trace that propagated to the top level.
  fatal,

  /// A clear failure that requires attention — e.g. an exception thrown by a
  /// Riverpod provider, a Dio error with a 5xx status, or an explicit
  /// [DebugKit.log.error] call.
  error,

  /// A potentially problematic condition — e.g. a 4xx HTTP error, a
  /// cancelled trace, or a warning-level log that carried an error string.
  warning;

  /// Short uppercase label shown in the console UI and export files.
  ///
  /// - [fatal]   → `'FATAL'`
  /// - [error]   → `'ERROR'`
  /// - [warning] → `'WARN'`
  String get label {
    return switch (this) {
      DebugErrorDigestSeverity.fatal => 'FATAL',
      DebugErrorDigestSeverity.error => 'ERROR',
      DebugErrorDigestSeverity.warning => 'WARN',
    };
  }

  /// Sort index — lower is more severe (used to sort digest entries).
  int get sortOrder {
    return switch (this) {
      DebugErrorDigestSeverity.fatal => 0,
      DebugErrorDigestSeverity.error => 1,
      DebugErrorDigestSeverity.warning => 2,
    };
  }
}
