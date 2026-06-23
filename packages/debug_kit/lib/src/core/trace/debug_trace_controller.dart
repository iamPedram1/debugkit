import 'dart:async';
import '../models/debug_trace.dart';
import '../models/debug_trace_event.dart';
import '../models/debug_trace_event_type.dart';
import '../models/debug_trace_status.dart';
import '../store/debug_trace_store.dart';
import '../debug_console_printer.dart';
import '../../utils/sanitizer/debug_log_sanitizer.dart';

/// Zone key used to propagate the active trace ID through async call stacks.
///
/// Set by [DebugTraceController.run] via [runZoned]. Read by
/// [DebugTraceController.activeTraceId], [DebugKitController.log], and all
/// adapter packages to attach trace correlation metadata without global
/// mutable state.
///
/// ```dart
/// final id = Zone.current[debugKitActiveTraceIdKey] as String?;
/// ```
const Symbol debugKitActiveTraceIdKey = #debugKitActiveTraceId;

/// Zone key used to propagate the active trace name through async call stacks.
///
/// Mirrors [debugKitActiveTraceIdKey] but carries the human-readable trace
/// name for convenient display in log entries without a store lookup.
const Symbol debugKitActiveTraceNameKey = #debugKitActiveTraceName;

/// Manages the complete trace lifecycle and exposes the public trace API.
///
/// Accessed via [DebugKit.trace] (wrapped by [DebugKitTrace]). All public
/// methods are strict no-ops when [_isEnabled] returns `false`, ensuring zero
/// overhead in disabled mode.
///
/// **Zone-based context propagation**: [run] wraps the callback in a
/// [runZoned] call that injects [debugKitActiveTraceIdKey] and
/// [debugKitActiveTraceNameKey] into the Zone. Every [DebugKit.log.*] call and
/// every adapter hook reads these values automatically, so logs and events
/// inside the callback are correlated without explicit plumbing.
class DebugTraceController {
  final DebugTraceStore _store;
  final DebugConsolePrinter? _consolePrinter;

  /// Callback that returns the current enabled state of DebugKit.
  ///
  /// Evaluated lazily so the controller honours runtime enable/disable changes
  /// without needing to be re-created.
  final bool Function() _isEnabled;

  int _idCounter = 0;
  int _eventIdCounter = 0;

  /// Creates a [DebugTraceController].
  ///
  /// - [store]: the [DebugTraceStore] where traces are persisted.
  /// - [isEnabled]: returns `true` when DebugKit is active.
  DebugTraceController({
    required DebugTraceStore store,
    required bool Function() isEnabled,
    DebugConsolePrinter? consolePrinter,
  })  : _store = store,
        _isEnabled = isEnabled,
        _consolePrinter = consolePrinter;

  /// The [DebugTraceStore] owned by this controller.
  DebugTraceStore get store => _store;

  // ---------------------------------------------------------------------------
  // Active trace context (Zone-based)
  // ---------------------------------------------------------------------------

  /// The active trace ID from the current Dart Zone, or `null` if no trace is
  /// running in this async context.
  ///
  /// Set automatically by [run]. Adapters and [DebugKitController.log] read
  /// this to attach trace metadata without explicit parameters.
  String? get activeTraceId =>
      Zone.current[debugKitActiveTraceIdKey] as String?;

  /// The active trace name from the current Dart Zone, or `null`.
  ///
  /// Mirrors [activeTraceId] but carries the display name.
  String? get activeTraceName =>
      Zone.current[debugKitActiveTraceNameKey] as String?;

  // ---------------------------------------------------------------------------
  // Public trace lifecycle API
  // ---------------------------------------------------------------------------

  /// Starts a new named trace and returns its stable trace ID.
  ///
  /// The trace begins in [DebugTraceStatus.running]. Call [end], [fail], or
  /// [cancel] to close it, or use [run] to manage the lifecycle automatically.
  ///
  /// If called inside an active [run] zone, the new trace's [DebugTrace.parentTraceId]
  /// is set to the outer trace's ID, supporting nested traces.
  ///
  /// Returns an empty string (and stores nothing) when DebugKit is disabled.
  ///
  /// - [name]: human-readable identifier, e.g. `'login_flow'`.
  /// - [metadata]: optional sanitized context attached to the trace root.
  ///
  /// ```dart
  /// final id = DebugKit.trace.start('checkout', metadata: {'items': '3'});
  /// // ... do work ...
  /// DebugKit.trace.end(traceId: id);
  /// ```
  String start(String name, {Map<String, String>? metadata}) {
    if (!_isEnabled()) return '';

    final id = _nextTraceId();
    final parentId = activeTraceId;
    final sanitizedName = DebugLogSanitizer.sanitizeMessage(name);
    final sanitizedMetadata = _sanitizeMetadata(metadata);
    final startedAt = DateTime.now();

    final trace = DebugTrace(
      id: id,
      name: sanitizedName,
      status: DebugTraceStatus.running,
      startedAt: startedAt,
      metadata: sanitizedMetadata,
      parentTraceId: parentId,
    );

    _store.startTrace(trace);
    _consolePrinter?.printTraceLifecycle(
      event: 'start',
      traceName: sanitizedName,
      traceId: id,
      startedAt: startedAt,
      metadata: sanitizedMetadata,
    );
    return id;
  }

  /// Records a named step event on the trace.
  ///
  /// Steps are the primary way to mark progress milestones inside a trace
  /// (e.g. `'validate_input'`, `'network_request_sent'`).
  ///
  /// If [traceId] is omitted, the active Zone trace ID is used. No-op if
  /// neither is available or DebugKit is disabled.
  ///
  /// - [name]: step description.
  /// - [traceId]: explicit trace ID; falls back to Zone value.
  /// - [metadata]: optional key-value context for this step.
  void step(String name, {String? traceId, Map<String, String>? metadata}) {
    if (!_isEnabled()) return;
    final id = traceId ?? activeTraceId;
    if (id == null || id.isEmpty) return;
    final sanitizedName = DebugLogSanitizer.sanitizeMessage(name);
    final sanitizedMetadata = _sanitizeMetadata(metadata);
    final traceName = _store.getTraceById(id)?.name ?? activeTraceName ?? id;

    _addEvent(
      traceId: id,
      message: sanitizedName,
      type: DebugTraceEventType.step,
      metadata: sanitizedMetadata,
    );
    _consolePrinter?.printTraceLifecycle(
      event: 'step',
      traceName: traceName,
      traceId: id,
      startedAt: _store.getTraceById(id)?.startedAt,
      metadata: sanitizedMetadata,
    );
  }

  /// Marks the trace as [DebugTraceStatus.success] and records the end time.
  ///
  /// If [traceId] is omitted, the active Zone trace ID is used. No-op if
  /// neither is available or DebugKit is disabled.
  void end({String? traceId}) {
    if (!_isEnabled()) return;
    final id = traceId ?? activeTraceId;
    if (id == null || id.isEmpty) return;
    final trace = _store.getTraceById(id);
    final endedAt = DateTime.now();
    _store.finishTrace(id, endedAt);
    if (trace != null) {
      _consolePrinter?.printTraceLifecycle(
        event: 'end',
        traceName: trace.name,
        traceId: id,
        startedAt: trace.startedAt,
        endedAt: endedAt,
        metadata: trace.metadata,
      );
    }
  }

  /// Marks the trace as [DebugTraceStatus.failed], records an error event, and
  /// stores a sanitized [errorSummary] on the trace.
  ///
  /// The [error] and [stackTrace] parameters mirror those of a standard Dart
  /// `catch` clause. The error string is sanitized before storage.
  ///
  /// If [traceId] is omitted, the active Zone trace ID is used. No-op if
  /// neither is available or DebugKit is disabled.
  ///
  /// Note: [run] calls this automatically when the callback throws — you
  /// usually don't need to call it directly.
  void fail(dynamic error, StackTrace? stackTrace, {String? traceId}) {
    if (!_isEnabled()) return;
    final id = traceId ?? activeTraceId;
    if (id == null || id.isEmpty) return;
    final trace = _store.getTraceById(id);
    final endedAt = DateTime.now();

    final sanitizedError = error != null
        ? DebugLogSanitizer.sanitizeMessage(error.toString())
        : null;

    _addEvent(
      traceId: id,
      message: sanitizedError ?? 'error',
      type: DebugTraceEventType.error,
      metadata: null,
    );

    _store.failTrace(id, endedAt, errorSummary: sanitizedError);
    if (trace != null) {
      _consolePrinter?.printTraceLifecycle(
        event: 'fail',
        traceName: trace.name,
        traceId: id,
        startedAt: trace.startedAt,
        endedAt: endedAt,
        error: sanitizedError,
        metadata: trace.metadata,
      );
    }
  }

  /// Marks the trace as [DebugTraceStatus.cancelled] and optionally records a
  /// reason event.
  ///
  /// Use this when the user or system deliberately aborts an operation that
  /// was in progress (e.g. user dismissed a modal while a network call was
  /// pending).
  ///
  /// If [traceId] is omitted, the active Zone trace ID is used. No-op if
  /// neither is available or DebugKit is disabled.
  ///
  /// - [reason]: optional human-readable cancellation reason.
  void cancel(String? reason, {String? traceId}) {
    if (!_isEnabled()) return;
    final id = traceId ?? activeTraceId;
    if (id == null || id.isEmpty) return;
    final trace = _store.getTraceById(id);
    final endedAt = DateTime.now();

    if (reason != null) {
      _addEvent(
        traceId: id,
        message: DebugLogSanitizer.sanitizeMessage(reason),
        type: DebugTraceEventType.custom,
        metadata: {'reason': 'cancelled'},
      );
    }

    _store.cancelTrace(id, endedAt);
    if (trace != null) {
      _consolePrinter?.printTraceLifecycle(
        event: 'cancel',
        traceName: trace.name,
        traceId: id,
        startedAt: trace.startedAt,
        endedAt: endedAt,
        error:
            reason == null ? null : DebugLogSanitizer.sanitizeMessage(reason),
        metadata: trace.metadata,
      );
    }
  }

  /// Runs [callback] inside a Dart Zone that carries the active trace context.
  ///
  /// This is the **recommended** way to trace async operations because it
  /// handles the full lifecycle automatically:
  ///
  /// 1. Calls [start] to create the trace.
  /// 2. Injects [debugKitActiveTraceIdKey] and [debugKitActiveTraceNameKey]
  ///    into the Zone so all logs and adapter events inside [callback] are
  ///    automatically correlated.
  /// 3. Calls [end] when [callback] completes normally.
  /// 4. Calls [fail] and **rethrows** when [callback] throws, preserving the
  ///    original exception and stack trace.
  ///
  /// When DebugKit is disabled, [callback] is called directly with zero
  /// overhead.
  ///
  /// - [name]: trace name.
  /// - [callback]: the async work to trace.
  /// - [metadata]: optional metadata attached to the trace root.
  ///
  /// ```dart
  /// await DebugKit.trace.run('login_flow', () async {
  ///   DebugKit.trace.step('validate_input');
  ///   await authRepository.login();
  ///   DebugKit.trace.step('login_success');
  /// }, metadata: {'source': 'login_button'});
  /// ```
  Future<T> run<T>(
    String name,
    Future<T> Function() callback, {
    Map<String, String>? metadata,
  }) async {
    if (!_isEnabled()) return callback();

    final sanitizedName = DebugLogSanitizer.sanitizeMessage(name);
    final traceId = start(sanitizedName, metadata: metadata);
    if (traceId.isEmpty) return callback();

    final zoneValues = {
      debugKitActiveTraceIdKey: traceId,
      debugKitActiveTraceNameKey: sanitizedName,
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
  // Internal helpers — called by adapter packages
  // ---------------------------------------------------------------------------

  /// Records a [DebugTraceEventType.network] event on the currently active trace.
  ///
  /// Called by the Dio adapter when a request starts, a response is received,
  /// or a request fails. No-op if no trace is active or DebugKit is disabled.
  ///
  /// - [message]: sanitized request description (e.g. `'GET /api/users · 200 · 142ms'`).
  /// - [requestId]: Dio request ID for cross-referencing with the log entry.
  /// - [durationMs]: round-trip duration in milliseconds.
  /// - [metadata]: additional sanitized key-value context.
  /// - [error]: sanitized error string if the request failed.
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

  /// Records a [DebugTraceEventType.navigation] event on the currently active trace.
  ///
  /// Called by the GoRouter adapter for push/pop/replace/remove events. No-op
  /// if no trace is active or DebugKit is disabled.
  ///
  /// - [message]: sanitized navigation description (e.g. `'push: /home'`).
  /// - [metadata]: optional route metadata (action, route_path, etc.).
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

  /// Records a [DebugTraceEventType.state] event on the currently active trace.
  ///
  /// Called by the Riverpod adapter for provider failures (and optionally
  /// updates). No-op if no trace is active or DebugKit is disabled.
  ///
  /// - [message]: sanitized state description.
  /// - [metadata]: optional provider metadata.
  /// - [error]: sanitized error string if the state event represents a failure.
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

  /// Records a [DebugTraceEventType.log] event on the currently active trace.
  ///
  /// Called by [DebugKitController.log] when a log entry is emitted inside an
  /// active trace zone. Keeps the trace timeline in sync with the log stream.
  /// No-op if no trace is active or DebugKit is disabled.
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
  // Private helpers
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

  /// Generates the next trace ID string. Format: `'trace_<n>'`.
  String _nextTraceId() => 'trace_${++_idCounter}';

  /// Generates the next event ID string. Format: `'evt_<n>'`.
  String _nextEventId() => 'evt_${++_eventIdCounter}';

  Map<String, String>? _sanitizeMetadata(Map<String, String>? metadata) {
    return DebugLogSanitizer.sanitizeMetadata(metadata);
  }
}
