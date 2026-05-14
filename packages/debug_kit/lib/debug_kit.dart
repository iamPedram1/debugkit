library debug_kit;

import 'src/core/controller/debug_kit_controller.dart';
import 'src/core/models/debug_log_level.dart';
import 'src/core/models/debug_log_source.dart';
import 'src/core/adapters/debug_kit_adapter.dart';

export 'src/core/models/debug_log_level.dart';
export 'src/core/models/debug_log_source.dart';
export 'src/core/models/debug_log_entry.dart';
export 'src/core/adapters/debug_kit_adapter.dart';
export 'src/ui/overlay/debug_kit_overlay.dart';
export 'src/ui/screens/debug_kit_console_screen.dart';

class DebugKit {
  static final DebugKitController _controller = DebugKitController();

  /// Initialize DebugKit with configuration.
  static void init({
    bool enabled = true,
    int maxLogs = 300,
    bool captureAppCallLocation = true,
    bool captureAppStackTrace = false,
    List<DebugKitAdapter> adapters = const [],
  }) {
    _controller.init(
      enabled: enabled,
      maxLogs: maxLogs,
      captureAppCallLocation: captureAppCallLocation,
      captureAppStackTrace: captureAppStackTrace,
      adapters: adapters,
    );
  }

  /// Access the logging API.
  static final DebugKitLog log = DebugKitLog(_controller);

  /// Access the internal controller (use with caution).
  static DebugKitController get controller => _controller;
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
