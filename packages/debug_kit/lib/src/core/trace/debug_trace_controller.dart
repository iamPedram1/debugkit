import 'dart:async';
import '../models/debug_trace.dart';
import '../models/debug_trace_event.dart';
import '../models/debug_trace_event_type.dart';
import '../models/debug_trace_status.dart';
import '../store/debug_trace_store.dart';
import '../../utils/sanitizer/debug_log_sanitizer.dart';

/// Zone key used to propagate the active trace ID through async call stacks.
///
/// Adapters and log calls can read this to attach trace correlation metadata
/// without any global mutable state.
const Symbol debugKitActiveTraceIdKey = #debugKitActiveTraceId;
const Symbol debugKitActiveTraceNameKey = #debugKitActiveTraceName;

/// Controls the trace lifecycle and provides the public trace API.
///
/// Accessed via [DebugKit.trace]. All methods are no-ops when [_enabled] is
/// false, ensuring zero overhead in disabled mode.
class DebugTraceController {
  final DebugTraceStore _store;
  final bool Function() _isEnabled;

  int _idCounter = 0;
  int _eventIdCounter = 0;

  DebugTraceController({
    required DebugTraceStore store,
    required bool Function() isEnabled,
  })  : _store = store,
        _isEnabled = isEnabled;

  DebugTraceStore get store => _store;

  // ---------------------------------------------------------------------------
  // Active trace context (Zone-based)
  // ---------------------------------------------------------------------------

  /// Returns the active trace ID from the current Zone, or null.
  String? get activeTraceId =>
      Zone.current[debugKitActiveTraceIdKey] as String?;

  /// Returns the active trace name from the current Zone, or null.
  String? get activeTraceName =>
      Zone.current[debugKitActiveTraceNameKey] as String?;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Starts a new trace with the given [name].
  ///
  /// If called inside an active [run] zone, the new trace will be nested
  /// under the parent trace via [parentTraceId].
  ///
  /// Returns the trace ID for use with [step], [end], [fail], and [cancel].
  String start(
    String name, {
    Map<String, String>? metadata,
  }) {
    if (!_isEnabled()) return '';

    final id = _nextTraceId();
    final parentId = activeTraceId;

    final trace = DebugTrace(
      id: id,
      name: name,
      status: DebugTraceStatus.running,
      startedAt: DateTime.now(),
      metadata: _sanitizeMetadata(metadata),
      parentTraceId: parentId,
    );

    _store.startTrace(trace);
    return id;
  }

  /// Records a named step event on the trace identified by [traceId].
  ///
  /// If [traceId] is omitted, uses the active Zone trace ID.
  void step(
    String name, {
    String? traceId,
    Map<String, String>? metadata,
  }) {
    if (!_isEnabled()) return;
    final id = traceId ?? activeTraceId;
    if (id == null || id.isEmpty) return;

    _addEvent(
      traceId: id,
      message: name,
      type: DebugTraceEventType.step,
      metadata: metadata,
    );
  }

  /// Marks the trace as successfully completed.
  ///
  /// If [traceId] is omitted, uses the active Zone trace ID.
  void end({String? traceId}) {
    if (!_isEnabled()) return;
    final id = traceId ?? activeTraceId;
    if (id == null || id.isEmpty) return;
    _store.finishTrace(id, DateTime.now());
  }

  /// Marks the trace as failed with an optional [error] and [stackTrace].
  ///
  /// If [traceId] is omitted, uses the active Zone trace ID.
  void fail(
    dynamic error,
    StackTrace? stackTrace, {
    String? traceId,
  }) {
    if (!_isEnabled()) return;
    final id = traceId ?? activeTraceId;
    if (id == null || id.isEmpty) return;

    final sanitizedError = error != null
        ? DebugLogSanitizer.sanitizeMessage(error.toString())
        : null;

    _addEvent(
      traceId: id,
      message: sanitizedError ?? 'error',
      type: DebugTraceEventType.error,
      metadata: null,
    );

    _store.failTrace(id, DateTime.now(), errorSummary: sanitizedError);
  }

  /// Marks the trace as cancelled with an optional [reason].
  ///
  /// If [traceId] is omitted, uses the active Zone trace ID.
  void cancel(String? reason, {String? traceId}) {
    if (!_isEnabled()) return;
    final id = traceId ?? activeTraceId;
    if (id == null || id.isEmpty) return;

    if (reason != null) {
      _addEvent(
        traceId: id,
        message: reason,
        type: DebugTraceEventType.custom,
        metadata: {'reason': 'cancelled'},
      );
    }

    _store.cancelTrace(id, DateTime.now());
  }

  /// Runs [callback] inside a Zone that propagates the active trace context.
  ///
  /// - Starts a trace named [name] before calling [callback].
  /// - Marks the trace as [DebugTraceStatus.success] when [callback] returns.
  /// - Marks the trace as [DebugTraceStatus.failed] if [callback] throws.
  /// - Always rethrows the original exception with the original stack trace.
  ///
  /// Logs and adapter events emitted inside [callback] will automatically
  /// carry the trace ID and name in their metadata.
  Future<T> run<T>(
    String name,
    Future<T> Function() callback, {
    Map<String, String>? metadata,
  }) async {
    if (!_isEnabled()) return callback();

    final traceId = start(name, metadata: metadata);
    if (traceId.isEmpty) return callback();

    final zoneValues = {
      debugKitActiveTraceIdKey: traceId,
      debugKitActiveTraceNameKey: name,
    };

    try {
      final result = await runZoned(callback, zoneValues: zoneValues);
      end(traceId: traceId);
      return result;
    } catch (e, s) {
      fail(e, s, traceId: traceId);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers used by adapters
  // ---------------------------------------------------------------------------

  /// Records a network event on the active trace (if any).
  ///
  /// Called by adapter packages. No-op if no trace is active.
  void recordNetworkEvent({
    required String message,
    String? requestId,
    int? durationMs,
    Map<String, String>? metadata,
    String? error,
  }) {
    if (!_isEnabled()) return;
    final id = activeTraceId;
    if (id == null || id.isEmpty) return;

    _addEvent(
      traceId: id,
      message: message,
      type: DebugTraceEventType.network,
      metadata: metadata,
      durationMs: durationMs,
      error: error,
      requestId: requestId,
    );
  }

  /// Records a navigation event on the active trace (if any).
  ///
  /// Called by adapter packages. No-op if no trace is active.
  void recordNavigationEvent({
    required String message,
    Map<String, String>? metadata,
  }) {
    if (!_isEnabled()) return;
    final id = activeTraceId;
    if (id == null || id.isEmpty) return;

    _addEvent(
      traceId: id,
      message: message,
      type: DebugTraceEventType.navigation,
      metadata: metadata,
    );
  }

  /// Records a state event on the active trace (if any).
  ///
  /// Called by adapter packages. No-op if no trace is active.
  void recordStateEvent({
    required String message,
    Map<String, String>? metadata,
    String? error,
  }) {
    if (!_isEnabled()) return;
    final id = activeTraceId;
    if (id == null || id.isEmpty) return;

    _addEvent(
      traceId: id,
      message: message,
      type: DebugTraceEventType.state,
      metadata: metadata,
      error: error,
    );
  }

  /// Records a log event on the active trace (if any).
  ///
  /// Called by the core controller when a log is emitted inside an active trace.
  void recordLogEvent({
    required String message,
    Map<String, String>? metadata,
  }) {
    if (!_isEnabled()) return;
    final id = activeTraceId;
    if (id == null || id.isEmpty) return;

    _addEvent(
      traceId: id,
      message: message,
      type: DebugTraceEventType.log,
      metadata: metadata,
    );
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _addEvent({
    required String traceId,
    required String message,
    required DebugTraceEventType type,
    Map<String, String>? metadata,
    int? durationMs,
    String? error,
    String? requestId,
  }) {
    final event = DebugTraceEvent(
      id: _nextEventId(),
      traceId: traceId,
      message: DebugLogSanitizer.sanitizeMessage(message),
      type: type,
      timestamp: DateTime.now(),
      durationMs: durationMs,
      metadata: _sanitizeMetadata(metadata),
      error: error != null ? DebugLogSanitizer.sanitizeMessage(error) : null,
      requestId: requestId,
    );
    _store.addEvent(traceId, event);
  }

  String _nextTraceId() => 'trace_${++_idCounter}';
  String _nextEventId() => 'evt_${++_eventIdCounter}';

  Map<String, String>? _sanitizeMetadata(Map<String, String>? metadata) {
    return DebugLogSanitizer.sanitizeMetadata(metadata);
  }
}
