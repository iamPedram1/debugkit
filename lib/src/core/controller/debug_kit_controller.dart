import 'package:flutter/foundation.dart';
import '../models/debug_kit_config.dart';
import '../models/debug_log_entry.dart';
import '../models/debug_log_level.dart';
import '../models/debug_log_source.dart';
import '../store/debug_log_store.dart';
import '../../utils/sanitizer/debug_log_sanitizer.dart';

class DebugKitController extends ChangeNotifier {
  static final DebugKitController _instance = DebugKitController._internal();
  factory DebugKitController() => _instance;
  DebugKitController._internal();

  late DebugLogStore _store;
  DebugKitConfig _config = const DebugKitConfig(enabled: false);

  DebugLogStore get store => _store;
  DebugKitConfig get config => _config;

  void init({
    bool enabled = true,
    int maxLogs = 300,
    bool captureAppCallLocation = true,
    bool captureAppStackTrace = false,
  }) {
    _config = DebugKitConfig(
      enabled: enabled,
      maxLogs: maxLogs,
      captureAppCallLocation: captureAppCallLocation,
      captureAppStackTrace: captureAppStackTrace,
    );
    _store = DebugLogStore(maxLogs: maxLogs);
    notifyListeners();
  }

  void log({
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
    if (!_config.enabled) return;

    final sanitizedMessage = DebugLogSanitizer.sanitizeMessage(message);
    final sanitizedError =
        error != null ? DebugLogSanitizer.sanitizeMessage(error) : null;

    String? location;
    if (_config.captureAppCallLocation && source == DebugLogSource.app) {
      location = _parseLocation(StackTrace.current);
    }

    final entry = DebugLogEntry(
      id: _store.getNextId(),
      level: level,
      source: source,
      message: sanitizedMessage,
      timestamp: DateTime.now(),
      error: sanitizedError,
      stackTrace: DebugLogSanitizer.trimStackTrace(stackTrace?.toString()),
      location: location,
      metadata: metadata,
      requestId: requestId,
      traceId: traceId,
      traceName: traceName,
      traceStep: traceStep,
    );

    _store.addLog(entry);
  }

  String? _parseLocation(StackTrace stackTrace) {
    try {
      final lines = stackTrace.toString().split('\n');
      // Skip the first few lines which are usually the logger itself
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('debug_kit_controller.dart') ||
            line.contains('debug_kit.dart') ||
            line.isEmpty) {
          continue;
        }

        final match = RegExp(r'package:[^ ]+\.dart:\d+:\d+').firstMatch(line);
        if (match != null) {
          final fullPath = match.group(0)!;
          return fullPath.split('/').last;
        }
      }
    } catch (_) {}
    return null;
  }

  void debug(String message,
      {String? error, StackTrace? stackTrace, Map<String, String>? metadata}) {
    log(
        message: message,
        level: DebugLogLevel.debug,
        source: DebugLogSource.app,
        error: error,
        stackTrace: stackTrace,
        metadata: metadata);
  }

  void info(String message,
      {String? error, StackTrace? stackTrace, Map<String, String>? metadata}) {
    log(
        message: message,
        level: DebugLogLevel.info,
        source: DebugLogSource.app,
        error: error,
        stackTrace: stackTrace,
        metadata: metadata);
  }

  void warning(String message,
      {String? error, StackTrace? stackTrace, Map<String, String>? metadata}) {
    log(
        message: message,
        level: DebugLogLevel.warning,
        source: DebugLogSource.app,
        error: error,
        stackTrace: stackTrace,
        metadata: metadata);
  }

  void error(String message,
      {dynamic error, StackTrace? stackTrace, Map<String, String>? metadata}) {
    log(
        message: message,
        level: DebugLogLevel.error,
        source: DebugLogSource.app,
        error: error?.toString(),
        stackTrace: stackTrace,
        metadata: metadata);
  }

  void userAction(String action, {Map<String, String>? metadata}) {
    log(
        message: action,
        level: DebugLogLevel.info,
        source: DebugLogSource.userAction,
        metadata: metadata);
  }
}
