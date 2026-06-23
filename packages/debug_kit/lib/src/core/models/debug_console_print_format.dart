/// Console output style used by DebugKit's mirrored terminal printing.
enum DebugConsolePrintFormat {
  /// Minimal output with the smallest useful signal.
  tiny,

  /// One-line output with a timestamp and source label.
  short,

  /// Compact developer-friendly output. This is the default.
  dev,

  /// Multi-line, report-style output with structured fields.
  detailed;

  /// Human-readable label for docs and diagnostics.
  String get label => switch (this) {
        DebugConsolePrintFormat.tiny => 'tiny',
        DebugConsolePrintFormat.short => 'short',
        DebugConsolePrintFormat.dev => 'dev',
        DebugConsolePrintFormat.detailed => 'detailed',
      };
}
