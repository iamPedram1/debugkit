library debug_kit;

import 'package:flutter/material.dart';

import 'src/core/controller/debug_kit_controller.dart';
export 'src/core/controller/debug_kit_controller.dart';
import 'src/core/models/debug_log_level.dart';
import 'src/core/models/debug_log_source.dart';
import 'src/core/adapters/debug_kit_adapter.dart';
import 'src/ui/screens/debug_kit_console_screen.dart';

export 'src/core/models/debug_log_level.dart';
export 'src/core/models/debug_log_source.dart';
export 'src/core/models/debug_log_entry.dart';
export 'src/core/adapters/debug_kit_adapter.dart';
export 'src/utils/sanitizer/debug_log_sanitizer.dart';
export 'src/ui/overlay/debug_kit_overlay.dart';
// Note: debug_kit_console_screen.dart is used internally by DebugKitOverlay.

class DebugKit {
  static final DebugKitController _controller = DebugKitController();

  /// Initialize DebugKit with configuration.
  static void init({
    bool enabled = true,
    int maxLogs = 300,
    bool captureAppCallLocation = true,
    bool captureAppStackTrace = false,
    List<DebugKitAdapter> adapters = const [],
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    _controller.init(
      enabled: enabled,
      maxLogs: maxLogs,
      captureAppCallLocation: captureAppCallLocation,
      captureAppStackTrace: captureAppStackTrace,
      adapters: adapters,
      navigatorKey: navigatorKey,
    );
  }

  /// Whether DebugKit is currently enabled.
  static bool get isEnabled => _controller.config.enabled;

  /// Clears all logs from the in-memory store.
  static void clearLogs() => _controller.store.clear();

  /// Access the logging API.
  static final DebugKitLog log = DebugKitLog(_controller);

  /// Access the internal controller (use with caution).
  static DebugKitController get controller => _controller;

  /// Opens the DebugKit console.
  ///
  /// If [context] is provided, it will try to find a [Navigator] to push the console.
  /// If no navigator is found in context, it will try to use the [navigatorKey] provided during [init].
  /// If still no navigator is found, it will log a warning.
  static void openConsole(BuildContext context) {
    NavigatorState? navigator = Navigator.maybeOf(context);

    if (navigator == null && _controller.config.navigatorKey != null) {
      navigator = _controller.config.navigatorKey!.currentState;
    }

    if (navigator != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const DebugKitConsoleScreen(),
          settings: const RouteSettings(name: 'debug_kit_console'),
        ),
      );
    } else {
      // ignore: avoid_print
      print(
          'DebugKit: Could not find Navigator. Ensure you are calling this from a context '
          'descended from Navigator or provide a navigatorKey during DebugKit.init().');
    }
  }
}

class DebugKitLog {
  final DebugKitController _controller;

  DebugKitLog(this._controller);

  void debug(String message,
      {String? error, StackTrace? stackTrace, Map<String, String>? metadata}) {
    _controller.debug(message,
        error: error, stackTrace: stackTrace, metadata: metadata);
  }

  void info(String message,
      {String? error, StackTrace? stackTrace, Map<String, String>? metadata}) {
    _controller.info(message,
        error: error, stackTrace: stackTrace, metadata: metadata);
  }

  void warning(String message,
      {String? error, StackTrace? stackTrace, Map<String, String>? metadata}) {
    _controller.warning(message,
        error: error, stackTrace: stackTrace, metadata: metadata);
  }

  void error(String message,
      {dynamic error, StackTrace? stackTrace, Map<String, String>? metadata}) {
    _controller.error(message,
        error: error, stackTrace: stackTrace, metadata: metadata);
  }

  void userAction(String action, {Map<String, String>? metadata}) {
    _controller.userAction(action, metadata: metadata);
  }

  void custom({
    required String message,
    required DebugLogLevel level,
    required DebugLogSource source,
    String? error,
    StackTrace? stackTrace,
    Map<String, String>? metadata,
    String? requestId,
    String? traceId,
    String? traceName,
    int? traceStep,
  }) {
    _controller.log(
      message: message,
      level: level,
      source: source,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
      requestId: requestId,
      traceId: traceId,
      traceName: traceName,
      traceStep: traceStep,
    );
  }
}
