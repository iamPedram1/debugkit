enum DebugLogLevel {
  debug,
  info,
  warning,
  error;

  String get label {
    return switch (this) {
      DebugLogLevel.debug => 'DBG',
      DebugLogLevel.info => 'INF',
      DebugLogLevel.warning => 'WRN',
      DebugLogLevel.error => 'ERR',
    };
  }
}
