import 'package:flutter/foundation.dart';

import 'debug_console_log_formatter.dart';
import 'models/debug_kit_config.dart';
import 'models/debug_log_entry.dart';
import 'models/debug_log_level.dart';
import 'models/debug_log_source.dart';

/// Internal sink that mirrors sanitized DebugKit data to the Flutter/IDE console.
class DebugConsolePrinter {
  final DebugKitConfig config;
  final void Function(String message) sink;
  final DebugConsoleLogFormatter formatter;

  DebugConsolePrinter({
    required this.config,
    void Function(String message)? sink,
    DebugConsoleLogFormatter? formatter,
  })  : sink = sink ?? debugPrint,
        formatter = formatter ?? DebugConsoleLogFormatter();

  void printLogEntry(DebugLogEntry entry) {
    if (!config.printToConsole || !_shouldPrintLogEntry(entry)) return;
    sink(
      formatter.formatLogEntry(
        entry,
        format: config.consolePrintFormat,
        colorizeConsoleOutput: config.colorizeConsoleOutput,
      ),
    );
  }

  void printTraceLifecycle({
    required String event,
    required String traceName,
    String? traceId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? error,
    Map<String, String>? metadata,
  }) {
    if (!config.printToConsole || !config.printTraceLogs) return;
    sink(
      formatter.formatTraceLifecycle(
        format: config.consolePrintFormat,
        event: event,
        traceName: traceName,
        traceId: traceId,
        startedAt: startedAt,
        endedAt: endedAt,
        error: error,
        metadata: metadata,
        colorizeConsoleOutput: config.colorizeConsoleOutput,
      ),
    );
  }

  bool _shouldPrintLogEntry(DebugLogEntry entry) {
    final isError = entry.level == DebugLogLevel.error;
    if (isError) return config.printErrorLogs;

    final isNetwork = _isNetwork(entry);
    final isRouter = entry.source == DebugLogSource.router;
    final isRiverpod = entry.source == DebugLogSource.riverpod;
    final isManual = entry.source == DebugLogSource.app ||
        entry.source == DebugLogSource.userAction;

    final categoryEnabled =
        switch ((isNetwork, isRouter, isRiverpod, isManual)) {
      (true, _, _, _) => config.printNetworkLogs,
      (_, true, _, _) => config.printRouterLogs,
      (_, _, true, _) => config.printRiverpodLogs,
      (_, _, _, true) => config.printManualLogs,
      _ => config.printManualLogs,
    };

    return categoryEnabled;
  }

  bool _isNetwork(DebugLogEntry entry) {
    final kind = entry.metadata?['kind']?.toLowerCase();
    return entry.source == DebugLogSource.dio || kind == 'networktransaction';
  }
}
