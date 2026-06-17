import 'package:flutter/material.dart';
import '../models/debug_kit_config.dart';
import '../models/debug_error_digest.dart';
import '../models/debug_log_entry.dart';
import '../models/debug_log_level.dart';
import '../models/debug_log_source.dart';
import '../adapters/debug_kit_adapter.dart';
import '../store/debug_log_store.dart';
import '../store/debug_trace_store.dart';
import '../trace/debug_trace_controller.dart';
import '../../utils/sanitizer/debug_log_sanitizer.dart';
import '../../utils/errors/debug_error_digest_builder.dart';

/// Central controller that owns the log store, trace store, and adapter lifecycle.
///
/// Implemented as a singleton — `DebugKitController()` always returns the same
/// instance. The public [DebugKit] facade delegates all work here.
///
/// Extends [ChangeNotifier] so the overlay and console UI can react to
/// initialization events (e.g. enabled/disabled toggle).
///
/// Adapter packages interact with DebugKit exclusively through the public API
/// of this class. They must never access `src/` internals directly.
class DebugKitController extends ChangeNotifier {
  static final DebugKitController _instance = DebugKitController._internal();

  /// Returns the singleton [DebugKitController] instance.
  factory DebugKitController() => _instance;
  DebugKitController._internal();

  late DebugLogStore _store;
  late DebugTraceStore _traceStore;
  late DebugTraceController _traceController;

  /// Active configuration snapshot. Starts with `enabled: false` until
  /// [init] is called.
  DebugKitConfig _config = const DebugKitConfig(enabled: false);
  final List<DebugKitAdapter> _adapters = [];

  /// The bounded in-memory log store.
  ///
  /// Prefer reading logs via [DebugKit.controller.store.logs]. Direct access
  /// is allowed for adapter packages that need to inspect or update entries.
  DebugLogStore get store => _store;

  /// The bounded in-memory trace store.
  DebugTraceStore get traceStore => _traceStore;

  /// The trace controller powering [DebugKit.trace].
  ///
  /// Adapter packages use [traceController.activeTraceId] and
  /// [traceController.recordNetworkEvent] / [recordNavigationEvent] /
  /// [recordStateEvent] to attach their events to the active trace.
  DebugTraceController get traceController => _traceController;

  /// The current configuration. Read-only after [init].
  DebugKitConfig get config => _config;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes DebugKit with the supplied configuration.
  ///
  /// Must be called once in `main()` before `runApp`. Can be called again to
  /// reinitialize (e.g. to change [enabled] at runtime), which disposes and
  /// re-attaches all adapters.
  ///
  /// Parameters:
  /// - [enabled]: master switch. `false` means all logging and trace calls
  ///   are no-ops and no overhead is incurred.
  /// - [maxLogs]: maximum log entries kept in memory. Defaults to `300`.
  /// - [captureAppCallLocation]: parse the call-site file/line for `app`
  ///   logs. Defaults to `true`.
  /// - [captureAppStackTrace]: reserved for future use. Defaults to `false`.
  /// - [adapters]: list of [DebugKitAdapter] instances to attach.
  /// - [navigatorKey]: required to open the console from non-widget contexts
  ///   or `MaterialApp.router` apps.
  /// - [maxTraces]: maximum [DebugTrace] instances kept in memory. Defaults to `50`.
  /// - [maxTraceEventsPerTrace]: maximum events per trace. Defaults to `200`.
  /// - [slowTraceThreshold]: duration above which [DebugTraceAnalyzer] warns
  ///   about a slow trace. Defaults to 3 seconds.
  /// - [groupRepeatedLogs]: collapse consecutive identical logs into a single
  ///   entry with a repeat counter. Defaults to `true`.
  void init({
    bool enabled = true,
    int maxLogs = 300,
    bool captureAppCallLocation = true,
    bool captureAppStackTrace = false,
    List<DebugKitAdapter> adapters = const [],
    GlobalKey<NavigatorState>? navigatorKey,
    int maxTraces = 50,
    int maxTraceEventsPerTrace = 200,
    Duration slowTraceThreshold = const Duration(seconds: 3),
    bool groupRepeatedLogs = true,
  }) {
    _config = DebugKitConfig(
      enabled: enabled,
      maxLogs: maxLogs,
      captureAppCallLocation: captureAppCallLocation,
      captureAppStackTrace: captureAppStackTrace,
      navigatorKey: navigatorKey,
      maxTraces: maxTraces,
      maxTraceEventsPerTrace: maxTraceEventsPerTrace,
      slowTraceThreshold: slowTraceThreshold,
      groupRepeatedLogs: groupRepeatedLogs,
    );
    _store = DebugLogStore(maxLogs: maxLogs, groupRepeated: groupRepeatedLogs);
    _traceStore = DebugTraceStore(
      maxTraces: maxTraces,
      maxEventsPerTrace: maxTraceEventsPerTrace,
    );
    _traceController = DebugTraceController(
      store: _traceStore,
      isEnabled: () => _config.enabled,
    );

    // Dispose old adapters before replacing them
    for (final adapter in _adapters) {
      adapter.dispose();
    }
    _adapters.clear();

    // Attach new adapters only when enabled
    if (enabled) {
      for (final adapter in adapters) {
        adapter.attach(this);
        _adapters.add(adapter);
      }
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Core log method
  // ---------------------------------------------------------------------------

  /// Sanitizes and stores a single log entry.
  ///
  /// This is the lowest-level method — all higher-level helpers ([debug],
  /// [info], [warning], [error], [userAction]) delegate here.
  ///
  /// **Sanitization guarantees:**
  /// - [message] is passed through [DebugLogSanitizer.sanitizeMessage].
  /// - [error] string is sanitized the same way.
  /// - [stackTrace] is trimmed to 25 lines via [DebugLogSanitizer.trimStackTrace].
  /// - [metadata] keys and values are sanitized via [DebugLogSanitizer.sanitizeMetadata].
  ///
  /// **Trace correlation:**
  /// If [traceId] is not provided, the active Zone trace ID (set by
  /// [DebugKit.trace.run]) is used automatically. A [DebugTraceEventType.log]
  /// event is also recorded on the active trace.
  ///
  /// Parameters:
  /// - [message]: human-readable description of the event. Required.
  /// - [level]: severity. Required.
  /// - [source]: subsystem origin. Required.
  /// - [error]: optional exception/error string.
  /// - [stackTrace]: optional stack trace (trimmed to 25 lines).
  /// - [metadata]: optional key-value pairs (values must be plain strings).
  /// - [requestId]: correlates Dio entries across pending → response updates.
  /// - [traceId]: explicit trace ID; falls back to Zone value if omitted.
  /// - [traceName]: trace display name; falls back to Zone value if omitted.
  /// - [traceStep]: optional step counter within the trace.
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

    // Resolve trace context from Zone if not explicitly provided
    final resolvedTraceId = traceId ?? _traceController.activeTraceId;
    final resolvedTraceName = traceName ?? _traceController.activeTraceName;

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
      metadata: DebugLogSanitizer.sanitizeMetadata(metadata),
      requestId: requestId,
      traceId: resolvedTraceId,
      traceName: resolvedTraceName,
      traceStep: traceStep,
    );

    _store.addLog(entry);

    // Mirror as a log event on the active trace
    if (resolvedTraceId != null) {
      _traceController.recordLogEvent(
        message: sanitizedMessage,
        metadata: entry.metadata,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Convenience log helpers
  // ---------------------------------------------------------------------------

  /// Logs a [DebugLogLevel.debug] entry from the app source.
  void debug(
    String message, {
    String? error,
    StackTrace? stackTrace,
    Map<String, String>? metadata,
  }) {
    log(
      message: message,
      level: DebugLogLevel.debug,
      source: DebugLogSource.app,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  /// Logs a [DebugLogLevel.info] entry from the app source.
  void info(
    String message, {
    String? error,
    StackTrace? stackTrace,
    Map<String, String>? metadata,
  }) {
    log(
      message: message,
      level: DebugLogLevel.info,
      source: DebugLogSource.app,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  /// Logs a [DebugLogLevel.warning] entry from the app source.
  void warning(
    String message, {
    String? error,
    StackTrace? stackTrace,
    Map<String, String>? metadata,
  }) {
    log(
      message: message,
      level: DebugLogLevel.warning,
      source: DebugLogSource.app,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  /// Logs a [DebugLogLevel.error] entry from the app source.
  ///
  /// [error] accepts any type and is converted via `.toString()`.
  void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, String>? metadata,
  }) {
    log(
      message: message,
      level: DebugLogLevel.error,
      source: DebugLogSource.app,
      error: error?.toString(),
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  /// Logs an [DebugLogLevel.info] entry with [DebugLogSource.userAction].
  ///
  /// Use this for deliberate user interactions (button taps, form submissions)
  /// that you want to surface separately in the console.
  void userAction(String action, {Map<String, String>? metadata}) {
    log(
      message: action,
      level: DebugLogLevel.info,
      source: DebugLogSource.userAction,
      metadata: metadata,
    );
  }

  // ---------------------------------------------------------------------------
  // Entry update helpers (used by adapters)
  // ---------------------------------------------------------------------------

  /// Replaces the log entry with [id] using the result of [update].
  ///
  /// No-op when DebugKit is disabled or no entry with [id] exists.
  void updateLog(int id, DebugLogEntry Function(DebugLogEntry) update) {
    if (!_config.enabled) return;
    _store.updateEntry(id, update);
  }

  /// Replaces the log entry whose [DebugLogEntry.requestId] matches [requestId]
  /// using the result of [update].
  ///
  /// No-op when DebugKit is disabled or no matching entry is found.
  /// Used by the Dio adapter to finalize a pending log entry with the response
  /// status code and duration.
  void updateLogByRequestId(
    String requestId,
    DebugLogEntry Function(DebugLogEntry) update,
  ) {
    if (!_config.enabled) return;
    final entry = _store.getEntryByRequestId(requestId);
    if (entry != null) {
      _store.updateEntry(entry.id, update);
    }
  }

  // ---------------------------------------------------------------------------
  // Error Digest
  // ---------------------------------------------------------------------------

  /// Builds and returns an [DebugErrorDigest] from the current log and trace
  /// stores.
  ///
  /// The digest groups repeated and related errors into [DebugErrorDigestEntry]
  /// instances, sorted by severity and frequency.
  ///
  /// This is a **pure, on-demand computation** — it reads the current store
  /// snapshots and returns a new [DebugErrorDigest] each time. Callers should
  /// avoid calling this on every frame build; instead, compute once per
  /// user interaction or store change, and cache the result locally.
  ///
  /// Returns an empty [DebugErrorDigest] when DebugKit is disabled.
  DebugErrorDigest buildErrorDigest() {
    if (!_config.enabled) {
      return DebugErrorDigest(
        generatedAt: DateTime.now(),
        totalErrors: 0,
        uniqueErrors: 0,
        entries: const [],
        topRepeatedErrors: const [],
        latestErrors: const [],
        failedTraceCount: 0,
        failedNetworkCount: 0,
      );
    }
    return DebugErrorDigestBuilder.build(
      logs: _store.logs.toList(),
      traces: _traceStore.traces.toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Walks [stackTrace] to find the first non-DebugKit frame and returns
  /// its `filename.dart:line:col` string for use as [DebugLogEntry.location].
  ///
  /// Returns `null` if no suitable frame is found or parsing fails.
  String? _parseLocation(StackTrace stackTrace) {
    try {
      final lines = stackTrace.toString().split('\n');
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

  @override
  void dispose() {
    for (final adapter in _adapters) {
      adapter.dispose();
    }
    _adapters.clear();
    super.dispose();
  }
}
