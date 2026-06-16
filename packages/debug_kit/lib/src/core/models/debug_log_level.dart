/// The severity level of a [DebugLogEntry].
///
/// Levels progress from least to most severe: [debug] → [info] → [warning] → [error].
/// Use [label] to get the short 3-character string used in the console UI and
/// exported log files.
enum DebugLogLevel {
  /// Verbose, low-priority information useful only during development.
  ///
  /// Examples: "Config loaded", "Cache hit for key X".
  debug,

  /// General informational messages about normal app behavior.
  ///
  /// Examples: "User signed in", "App started".
  info,

  /// Something unexpected happened but the app can continue.
  ///
  /// Examples: "Slow network response", "Retry attempt 2 of 3".
  warning,

  /// A failure that requires attention or indicates broken behavior.
  ///
  /// Examples: "Auth failed", "Unhandled exception".
  error;

  /// Short uppercase label shown in the console UI and export files.
  ///
  /// - [debug] → `'DBG'`
  /// - [info]  → `'INF'`
  /// - [warning] → `'WRN'`
  /// - [error] → `'ERR'`
  String get label {
    return switch (this) {
      DebugLogLevel.debug => 'DBG',
      DebugLogLevel.info => 'INF',
      DebugLogLevel.warning => 'WRN',
      DebugLogLevel.error => 'ERR',
    };
  }
}
