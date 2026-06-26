/// DebugKit — a mobile-first in-app DevTools cockpit for Flutter apps.
///
/// Import this library and call [DebugKit.init] once in `main()` to enable
/// the log console, trace system, and adapter integrations.
///
/// ```dart
/// import 'package:debug_kit/debug_kit.dart';
///
/// void main() {
///   DebugKit.init(enabled: kDebugMode);
///   runApp(const MyApp());
/// }
/// ```
library debug_kit;

import 'package:flutter/material.dart';

import 'src/core/controller/debug_kit_controller.dart';
export 'src/core/controller/debug_kit_controller.dart';
import 'src/core/models/debug_error_digest.dart';
import 'src/core/models/debug_console_print_format.dart';
import 'src/core/models/debug_log_level.dart';
import 'src/core/models/debug_log_source.dart';
import 'src/core/models/debug_state_event.dart';
import 'src/core/adapters/debug_kit_adapter.dart';
import 'src/core/trace/debug_trace_controller.dart';
import 'src/ui/overlay/debug_kit_console_launcher.dart';

export 'src/core/models/debug_log_level.dart';
export 'src/core/models/debug_log_source.dart';
export 'src/core/models/debug_console_print_format.dart';
export 'src/core/models/debug_log_entry.dart';
export 'src/core/models/debug_state_diff_entry.dart';
export 'src/core/models/debug_state_diff_type.dart';
export 'src/core/models/debug_state_event.dart';
export 'src/core/models/debug_state_event_type.dart';
export 'src/core/models/debug_trace.dart';
export 'src/core/models/debug_trace_event.dart';
export 'src/core/models/debug_trace_event_type.dart';
export 'src/core/models/debug_trace_status.dart';
export 'src/core/models/debug_error_digest.dart';
export 'src/core/models/debug_error_digest_entry.dart';
export 'src/core/models/debug_error_digest_severity.dart';
export 'src/core/models/debug_network_filter_state.dart';
export 'src/core/models/debug_network_summary.dart';
export 'src/core/models/debug_network_endpoint_stats.dart';
export 'src/core/models/debug_network_status_breakdown.dart';
export 'src/core/models/debug_network_sort_option.dart';
export 'src/core/models/debug_network_status_family.dart';
export 'src/core/models/debug_network_transaction.dart';
export 'src/core/models/debug_network_transaction_phase.dart';
export 'src/core/adapters/debug_kit_adapter.dart';
export 'src/core/trace/debug_trace_controller.dart'
    show
        DebugTraceController,
        debugKitActiveTraceIdKey,
        debugKitActiveTraceNameKey;
export 'src/utils/sanitizer/debug_log_sanitizer.dart';
export 'src/utils/state/debug_state_diff_builder.dart';
export 'src/ui/overlay/debug_kit_overlay.dart';
// Note: DebugKitConsoleScreen is used internally by DebugKitOverlay and is
// not part of the public API.

/// Top-level facade for DebugKit.
///
/// All interaction should go through this class. The singleton
/// [DebugKitController] is owned here and is not intended to be constructed
/// directly by application code.
///
/// **Setup (5 lines):**
/// ```dart
/// void main() {
///   final dio = Dio();
///   DebugKit.init(enabled: kDebugMode, adapters: [DebugKitDioAdapter(dio)]);
///   runApp(MaterialApp.router(
///     builder: (ctx, child) => DebugKitOverlay(child: child!),
///   ));
/// }
/// ```
class DebugKit {
  static final DebugKitController _controller = DebugKitController();

  /// Initializes DebugKit with the supplied configuration.
  ///
  /// Must be called once, before `runApp`, in your `main()` function. Safe to
  /// call again if you need to change configuration at runtime — all adapters
  /// are disposed and re-attached.
  ///
  /// Parameters:
  /// - [enabled]: master on/off switch. Pass `kDebugMode` to disable in
  ///   release builds automatically. Defaults to `true`.
  /// - [maxLogs]: log buffer capacity. Oldest entries are evicted when full.
  ///   Defaults to `300`.
  /// - [captureAppCallLocation]: parse call-site file/line for `app` logs.
  ///   Defaults to `true`.
  /// - [captureAppStackTrace]: reserved for future use. Defaults to `false`.
  /// - [adapters]: list of [DebugKitAdapter] instances (Dio, GoRouter, …).
  /// - [navigatorKey]: required for `MaterialApp.router` apps and for
  ///   context-free `DebugKit.open()` / `DebugKit.close()` calls to target a
  ///   navigator.
  /// - [disableDefaultOverlayButton]: hides the built-in floating launcher
  ///   button while keeping the DebugKit overlay mounted. Defaults to `false`.
  /// - [maxTraces]: trace buffer capacity. Defaults to `50`.
  /// - [maxTraceEventsPerTrace]: per-trace event limit. Defaults to `200`.
  /// - [maxStateEvents]: state-event buffer capacity. Defaults to `500`.
  /// - [slowTraceThreshold]: duration that triggers a "slow trace" health
  ///   warning. Defaults to 3 seconds.
  /// - [slowRequestThresholdMs]: duration above which a network request is
  ///   treated as slow in the Network Summary. Defaults to 500ms.
  /// - [groupRepeatedLogs]: collapse consecutive identical log entries into a
  ///   single row with a `×N` repeat badge. Defaults to `true`.
  /// - [printToConsole]: mirror sanitized logs to the Flutter / IDE console.
  ///   Defaults to `true`.
  /// - [consolePrintFormat]: output style used for console mirroring.
  ///   Defaults to [DebugConsolePrintFormat.dev].
  /// - [colorizeConsoleOutput]: whether terminal output uses ANSI colors.
  ///   Defaults to `true`.
  static void init({
    bool enabled = true,
    int maxLogs = 300,
    bool captureAppCallLocation = true,
    bool captureAppStackTrace = false,
    List<DebugKitAdapter> adapters = const [],
    GlobalKey<NavigatorState>? navigatorKey,
    bool disableDefaultOverlayButton = false,
    int maxTraces = 50,
    int maxTraceEventsPerTrace = 200,
    Duration slowTraceThreshold = const Duration(seconds: 3),
    int slowRequestThresholdMs = 500,
    bool groupRepeatedLogs = true,
    bool printToConsole = true,
    bool printManualLogs = true,
    bool printNetworkLogs = true,
    bool printRouterLogs = true,
    bool printRiverpodLogs = true,
    bool printTraceLogs = true,
    bool printErrorLogs = true,
    DebugConsolePrintFormat consolePrintFormat = DebugConsolePrintFormat.dev,
    bool colorizeConsoleOutput = true,
    int maxStateEvents = 500,
  }) {
    resetDebugKitConsoleLauncherState();
    _controller.init(
      enabled: enabled,
      maxLogs: maxLogs,
      captureAppCallLocation: captureAppCallLocation,
      captureAppStackTrace: captureAppStackTrace,
      adapters: adapters,
      navigatorKey: navigatorKey,
      disableDefaultOverlayButton: disableDefaultOverlayButton,
      maxTraces: maxTraces,
      maxTraceEventsPerTrace: maxTraceEventsPerTrace,
      slowTraceThreshold: slowTraceThreshold,
      slowRequestThresholdMs: slowRequestThresholdMs,
      groupRepeatedLogs: groupRepeatedLogs,
      printToConsole: printToConsole,
      printManualLogs: printManualLogs,
      printNetworkLogs: printNetworkLogs,
      printRouterLogs: printRouterLogs,
      printRiverpodLogs: printRiverpodLogs,
      printTraceLogs: printTraceLogs,
      printErrorLogs: printErrorLogs,
      consolePrintFormat: consolePrintFormat,
      colorizeConsoleOutput: colorizeConsoleOutput,
      maxStateEvents: maxStateEvents,
    );
  }

  /// Whether DebugKit is currently active.
  ///
  /// Returns `false` until [init] is called, or when initialized with
  /// `enabled: false`.
  static bool get isEnabled => _controller.config.enabled;

  /// Removes all log entries from the in-memory store.
  ///
  /// No-op when [isEnabled] is `false`.
  static void clearLogs() => _controller.store.clear();

  /// Removes all trace records from the in-memory store.
  ///
  /// No-op when [isEnabled] is `false`.
  static void clearTraces() => _controller.traceStore.clear();

  /// Removes all state events from the in-memory store.
  ///
  /// No-op when [isEnabled] is `false`.
  static void clearStateEvents() => _controller.clearStateEvents();

  /// Removes all network transaction logs from the in-memory store.
  ///
  /// No-op when [isEnabled] is `false`.
  static void clearNetworkTransactions() =>
      _controller.clearNetworkTransactions();

  /// Opens the DebugKit console without requiring a [BuildContext].
  ///
  /// This is useful when the host app already has its own debug menu or
  /// sheet. If DebugKit is disabled or no navigator is available yet, this
  /// safely does nothing.
  static void open() => openDebugKitConsole();

  /// Closes the DebugKit console if it is currently open.
  ///
  /// Safe to call before the overlay is mounted, when DebugKit is disabled,
  /// or when no navigator is available.
  static void close() => closeDebugKitConsole();

  /// Toggles the DebugKit console open/closed state.
  ///
  /// Safe to call before the overlay is mounted or when DebugKit is disabled.
  static void toggle() {
    if (isDebugKitConsoleOpen) {
      closeDebugKitConsole();
    } else {
      openDebugKitConsole();
    }
  }

  /// Builds and returns an error digest from the current log and trace stores.
  ///
  /// Groups repeated and related errors into a single [DebugErrorDigest] that
  /// summarizes what failed, how often, and where.
  ///
  /// This is a pure, on-demand computation. Do not call on every frame —
  /// compute once per user interaction or store change and cache the result.
  ///
  /// ```dart
  /// final digest = DebugKit.errors.buildDigest();
  /// print('Unique errors: ${digest.uniqueErrors}');
  /// ```
  static final DebugKitErrors errors = DebugKitErrors(_controller);

  /// The manual logging API.
  ///
  /// Use the convenience methods for common cases:
  /// ```dart
  /// DebugKit.log.debug('Cache hit', metadata: {'key': 'user_42'});
  /// DebugKit.log.info('User signed in');
  /// DebugKit.log.warning('Slow network', metadata: {'url': '/api/feed'});
  /// DebugKit.log.error('Auth failed', error: e, stackTrace: s);
  /// DebugKit.log.userAction('Tapped checkout button');
  /// ```
  static final DebugKitLog log = DebugKitLog(_controller);

  /// The generic state-management API.
  static final DebugKitState state = DebugKitState(_controller);

  /// The trace API.
  ///
  /// Use [DebugKitTrace.run] for scoped async tracing (recommended):
  /// ```dart
  /// await DebugKit.trace.run('login_flow', () async {
  ///   DebugKit.trace.step('validate_input');
  ///   await authRepo.login();
  /// });
  /// ```
  ///
  /// Or use [DebugKitTrace.start] / [DebugKitTrace.end] for manual control:
  /// ```dart
  /// final id = DebugKit.trace.start('checkout');
  /// DebugKit.trace.step('validate_cart', traceId: id);
  /// DebugKit.trace.end(traceId: id);
  /// ```
  static final DebugKitTrace trace = DebugKitTrace(_controller);

  /// Direct access to the internal [DebugKitController].
  ///
  /// Intended for adapter packages that need to call [DebugKitController.log]
  /// or [DebugKitController.traceController] directly. Application code should
  /// use [log] and [trace] instead.
  static DebugKitController get controller => _controller;

  /// Pushes the [DebugKitConsoleScreen] onto the nearest [Navigator].
  ///
  /// Resolution order:
  /// 1. [Navigator.maybeOf(context)] — uses the navigator in the widget tree.
  /// 2. [DebugKitConfig.navigatorKey] — falls back to the key provided during
  ///    [init] when no navigator is found in the context.
  /// 3. Prints a warning if neither resolves.
  ///
  /// For apps using `MaterialApp.router`, always provide a [navigatorKey]
  /// during [init] because the router manages navigation outside the widget
  /// tree context.
  static void openConsole(BuildContext context) {
    openDebugKitConsole(context: context);
  }
}

// ---------------------------------------------------------------------------
// DebugKitState — generic state event API
// ---------------------------------------------------------------------------

/// The generic state-management API accessed via [DebugKit.state].
class DebugKitState {
  final DebugKitController _controller;

  /// @nodoc — constructed by [DebugKit].
  DebugKitState(this._controller);

  /// Records a sanitized state event for the State tab.
  void record(DebugStateEvent event) => _controller.recordStateEvent(event);

  /// Clears all recorded state events.
  void clear() => _controller.clearStateEvents();

  /// Pauses state-event recording.
  void pause() => _controller.pauseStateRecording();

  /// Resumes state-event recording.
  void resume() => _controller.resumeStateRecording();

  /// Whether recording is currently paused.
  bool get isPaused => _controller.isStateRecordingPaused;
}

// ---------------------------------------------------------------------------
// DebugKitLog — manual logging API
// ---------------------------------------------------------------------------

/// The manual logging API accessed via [DebugKit.log].
///
/// All methods sanitize input before storage. They are strict no-ops when
/// DebugKit is disabled. When called inside an active [DebugKit.trace.run]
/// zone, the log entry automatically carries the trace ID and a corresponding
/// [DebugTraceEventType.log] event is recorded on the active trace.
class DebugKitLog {
  final DebugKitController _controller;

  /// @nodoc — constructed by [DebugKit].
  DebugKitLog(this._controller);

  /// Logs a [DebugLogLevel.debug] entry.
  ///
  /// Use for verbose, development-only information.
  ///
  /// - [message]: sanitized description of the event.
  /// - [error]: optional exception string.
  /// - [stackTrace]: optional stack trace (trimmed to 25 lines).
  /// - [metadata]: optional key-value context.
  void debug(
    String message, {
    String? error,
    StackTrace? stackTrace,
    Map<String, String>? metadata,
  }) {
    _controller.debug(message,
        error: error, stackTrace: stackTrace, metadata: metadata);
  }

  /// Logs a [DebugLogLevel.info] entry.
  ///
  /// Use for normal, noteworthy app events (sign-in, navigation, startup).
  void info(
    String message, {
    String? error,
    StackTrace? stackTrace,
    Map<String, String>? metadata,
  }) {
    _controller.info(message,
        error: error, stackTrace: stackTrace, metadata: metadata);
  }

  /// Logs a [DebugLogLevel.warning] entry.
  ///
  /// Use when something unexpected happened but the app can continue.
  void warning(
    String message, {
    String? error,
    StackTrace? stackTrace,
    Map<String, String>? metadata,
  }) {
    _controller.warning(message,
        error: error, stackTrace: stackTrace, metadata: metadata);
  }

  /// Logs a [DebugLogLevel.error] entry.
  ///
  /// Use for failures that require attention.
  ///
  /// - [error]: accepts any type — converted via `.toString()`.
  void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, String>? metadata,
  }) {
    _controller.error(message,
        error: error, stackTrace: stackTrace, metadata: metadata);
  }

  /// Logs a [DebugLogLevel.info] entry with [DebugLogSource.userAction].
  ///
  /// Use this for intentional user interactions (button taps, swipes, form
  /// submissions) that are worth tracking separately from informational logs.
  ///
  /// - [action]: description of what the user did.
  /// - [metadata]: optional context (e.g. screen name, element label).
  void userAction(String action, {Map<String, String>? metadata}) {
    _controller.userAction(action, metadata: metadata);
  }

  /// Logs an entry with full control over all fields.
  ///
  /// Use when none of the convenience methods fit your use case — for example,
  /// when building a custom adapter that needs a non-`app` source or a
  /// specific [requestId] / [traceId].
  ///
  /// - [message]: sanitized description. Required.
  /// - [level]: severity. Required.
  /// - [source]: subsystem origin. Required.
  /// - [requestId]: correlates with a Dio pending entry.
  /// - [traceId]: explicit trace ID; falls back to Zone value if omitted.
  /// - [traceName]: trace display name; falls back to Zone value if omitted.
  /// - [traceStep]: optional step counter within the trace.
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

// ---------------------------------------------------------------------------
// DebugKitTrace — trace API
// ---------------------------------------------------------------------------

/// The trace API accessed via [DebugKit.trace].
///
/// Traces group a sequence of timestamped events into a named timeline so you
/// can understand exactly what happened during a user flow, network call, or
/// background task.
///
/// **Recommended — scoped async trace:**
/// ```dart
/// await DebugKit.trace.run('login_flow', () async {
///   DebugKit.trace.step('validate_input');
///   await authRepository.login(email, password);
///   DebugKit.trace.step('login_success');
/// }, metadata: {'source': 'login_button'});
/// ```
///
/// **Manual trace (for synchronous or non-async flows):**
/// ```dart
/// final id = DebugKit.trace.start('checkout', metadata: {'items': '3'});
/// DebugKit.trace.step('validate_cart', traceId: id);
/// DebugKit.trace.step('apply_discount', traceId: id);
/// DebugKit.trace.end(traceId: id);
/// ```
///
/// All methods are strict no-ops when DebugKit is disabled.
class DebugKitTrace {
  final DebugKitController _controller;

  /// @nodoc — constructed by [DebugKit].
  DebugKitTrace(this._controller);

  DebugTraceController get _tc => _controller.traceController;

  /// Starts a new named trace and returns its stable trace ID.
  ///
  /// The trace begins in [DebugTraceStatus.running]. You are responsible for
  /// closing it with [end], [fail], or [cancel]. Prefer [run] to manage the
  /// lifecycle automatically.
  ///
  /// When called inside an active [run] zone, the new trace's
  /// [DebugTrace.parentTraceId] is set to the outer trace's ID.
  ///
  /// Returns an empty string when DebugKit is disabled.
  ///
  /// - [name]: human-readable identifier for the trace (e.g. `'login_flow'`).
  /// - [metadata]: optional sanitized context attached to the trace root.
  String start(String name, {Map<String, String>? metadata}) =>
      _tc.start(name, metadata: metadata);

  /// Records a named step event on the trace.
  ///
  /// Steps mark progress milestones (e.g. `'validate_input'`,
  /// `'cache_miss'`, `'network_request_sent'`).
  ///
  /// If [traceId] is omitted, the active Zone trace ID (set by [run]) is
  /// used. No-op if neither is available or DebugKit is disabled.
  ///
  /// - [name]: step description.
  /// - [traceId]: explicit trace ID; falls back to Zone value.
  /// - [metadata]: optional context for this step.
  void step(String name, {String? traceId, Map<String, String>? metadata}) =>
      _tc.step(name, traceId: traceId, metadata: metadata);

  /// Marks the trace as [DebugTraceStatus.success] and records the end time.
  ///
  /// If [traceId] is omitted, the active Zone trace ID is used.
  void end({String? traceId}) => _tc.end(traceId: traceId);

  /// Marks the trace as [DebugTraceStatus.failed] with the given [error].
  ///
  /// Records an [DebugTraceEventType.error] event and stores a sanitized
  /// error summary on the trace. The [error] string is sanitized before
  /// storage.
  ///
  /// If [traceId] is omitted, the active Zone trace ID is used.
  ///
  /// Note: [run] calls this automatically when the callback throws — you
  /// rarely need to call it directly.
  void fail(dynamic error, StackTrace? stackTrace, {String? traceId}) =>
      _tc.fail(error, stackTrace, traceId: traceId);

  /// Marks the trace as [DebugTraceStatus.cancelled].
  ///
  /// Records an optional [DebugTraceEventType.custom] event with the
  /// cancellation reason. Use this when an operation is deliberately aborted
  /// rather than failing due to an error.
  ///
  /// If [traceId] is omitted, the active Zone trace ID is used.
  ///
  /// - [reason]: optional human-readable cancellation description.
  void cancel(String? reason, {String? traceId}) =>
      _tc.cancel(reason, traceId: traceId);

  /// Runs [callback] inside a Dart Zone that automatically propagates the
  /// active trace context to all logs and adapter events.
  ///
  /// **Lifecycle:**
  /// 1. [start] is called to create the trace.
  /// 2. [callback] runs inside a [runZoned] scope that injects the trace ID
  ///    and name. All [DebugKit.log.*] calls and adapter hooks (Dio, GoRouter,
  ///    Riverpod) inside [callback] are automatically correlated.
  /// 3. [end] is called when [callback] returns normally.
  /// 4. [fail] is called and the original exception is **rethrown** when
  ///    [callback] throws, preserving the stack trace.
  ///
  /// When DebugKit is disabled, [callback] is called directly with zero
  /// overhead.
  ///
  /// - [name]: trace name (e.g. `'login_flow'`).
  /// - [callback]: the async work to trace.
  /// - [metadata]: optional metadata attached to the trace root.
  ///
  /// ```dart
  /// try {
  ///   await DebugKit.trace.run('refresh_feed', () async {
  ///     DebugKit.trace.step('fetch_posts');
  ///     final posts = await postsRepo.fetchLatest();
  ///     DebugKit.trace.step('render_posts', metadata: {'count': '${posts.length}'});
  ///   });
  /// } catch (e) {
  ///   // The trace is already marked failed — just handle the error here.
  /// }
  /// ```
  Future<T> run<T>(
    String name,
    Future<T> Function() callback, {
    Map<String, String>? metadata,
  }) =>
      _tc.run(name, callback, metadata: metadata);
}

// ---------------------------------------------------------------------------
// DebugKitErrors — error digest API
// ---------------------------------------------------------------------------

/// The error digest API accessed via [DebugKit.errors].
///
/// Provides on-demand access to the [DebugErrorDigest] — a grouped,
/// de-duplicated summary of all errors observed in the current session.
///
/// ```dart
/// final digest = DebugKit.errors.buildDigest();
/// print('Unique errors: ${digest.uniqueErrors}');
/// for (final entry in digest.entries) {
///   print('${entry.title} ×${entry.count}');
/// }
/// ```
class DebugKitErrors {
  final DebugKitController _controller;

  /// @nodoc — constructed by [DebugKit].
  DebugKitErrors(this._controller);

  /// Builds and returns a fresh [DebugErrorDigest] from the current log and
  /// trace store contents.
  ///
  /// This is a pure, on-demand computation — it reads the current store
  /// snapshot and returns a new digest each time. Callers should avoid
  /// calling this on every frame build; cache the result and recompute only
  /// when the log store notifies listeners of a change.
  ///
  /// Returns an empty [DebugErrorDigest] when DebugKit is disabled.
  DebugErrorDigest buildDigest() => _controller.buildErrorDigest();
}
