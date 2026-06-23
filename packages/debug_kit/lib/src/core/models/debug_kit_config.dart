import 'package:flutter/material.dart';
import 'debug_console_print_format.dart';

/// Immutable configuration snapshot used by [DebugKitController].
///
/// Created during [DebugKit.init] and stored on the controller. Read by the
/// controller, adapters, and the overlay to decide whether to perform work.
///
/// All fields have safe, production-usable defaults.
class DebugKitConfig {
  /// Whether DebugKit is active.
  ///
  /// When `false`, all logging and trace calls are no-ops, the overlay is
  /// hidden, and zero runtime overhead is incurred.
  ///
  /// Recommended usage in production apps:
  /// ```dart
  /// DebugKit.init(enabled: kDebugMode);
  /// ```
  final bool enabled;

  /// Maximum number of log entries kept in memory at one time.
  ///
  /// Grouped (repeated) entries count as a single slot regardless of their
  /// [DebugLogEntry.repeatCount]. Defaults to `300`.
  final int maxLogs;

  /// Whether to capture the call-site file name and line for [DebugLogSource.app] entries.
  ///
  /// When `true`, [DebugKitController.log] inspects [StackTrace.current] and
  /// extracts the first non-DebugKit frame as a `filename.dart:line:col`
  /// string stored in [DebugLogEntry.location].
  ///
  /// Defaults to `true`. Disable if you observe performance impact on
  /// low-end devices.
  final bool captureAppCallLocation;

  /// Whether to capture the full stack trace for [DebugLogSource.app] entries.
  ///
  /// Not currently used by the core — reserved for a future opt-in feature.
  /// Defaults to `false`.
  final bool captureAppStackTrace;

  /// Optional [NavigatorState] key used by [DebugKit.openConsole] and the
  /// draggable overlay button to push the console screen.
  ///
  /// Required when the calling context does not have a [Navigator] ancestor
  /// (e.g. when opening the console from a non-widget context, or from an
  /// app using `MaterialApp.router`).
  ///
  /// Pass the same key to both `DebugKit.init` and your `GoRouter` /
  /// `MaterialApp.router` configuration:
  /// ```dart
  /// final _navKey = GlobalKey<NavigatorState>();
  ///
  /// DebugKit.init(navigatorKey: _navKey);
  ///
  /// GoRouter(navigatorKey: _navKey, ...);
  /// ```
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Maximum number of [DebugTrace] instances kept in memory.
  ///
  /// When the store reaches [maxTraces], the oldest *completed* trace is
  /// evicted. If all traces are running, the oldest is evicted regardless.
  /// Defaults to `50`.
  final int maxTraces;

  /// Maximum number of [DebugTraceEvent] instances stored per trace.
  ///
  /// When a trace reaches [maxTraceEventsPerTrace], the oldest event is
  /// dropped before the newest is appended.
  /// Defaults to `200`.
  final int maxTraceEventsPerTrace;

  /// Duration above which a completed trace is flagged as slow by
  /// [DebugTraceAnalyzer].
  ///
  /// Defaults to 3 seconds.
  final Duration slowTraceThreshold;

  /// Duration in milliseconds above which a network request is considered
  /// slow by the Network Summary builder.
  ///
  /// Defaults to `500`.
  final int slowRequestThresholdMs;

  /// Whether consecutive identical log entries are collapsed into a single
  /// grouped entry with a [DebugLogEntry.repeatCount] counter.
  ///
  /// When `true` (the default), the store compares each incoming entry's
  /// [DebugLogEntry.fingerprint] against the tail entry. If they match, the
  /// tail entry is updated in-place rather than appending a new row. The
  /// console UI then shows a `×N` repeat badge.
  ///
  /// This mirrors Chrome DevTools console behavior and keeps the log list
  /// readable during high-frequency repeated events (e.g. polling, retries).
  ///
  /// Only *consecutive* duplicates are grouped — if a different log appears
  /// between two identical entries they remain separate. This matches
  /// Chrome's behavior and is more predictable than global deduplication.
  ///
  /// Set to `false` if you need every emission as an independent row, or
  /// when you are programmatically processing the raw log stream.
  ///
  /// Defaults to `true`.
  final bool groupRepeatedLogs;

  /// Whether sanitized DebugKit logs should also be mirrored to the Flutter
  /// / IDE console.
  ///
  /// Defaults to `true`.
  final bool printToConsole;

  /// Whether manually emitted app logs should be mirrored to the console.
  ///
  /// Applies to [DebugLogSource.app] and [DebugLogSource.userAction].
  /// Defaults to `true`.
  final bool printManualLogs;

  /// Whether network logs from adapters should be mirrored to the console.
  ///
  /// Defaults to `true`.
  final bool printNetworkLogs;

  /// Whether navigation logs from the GoRouter adapter should be mirrored to
  /// the console.
  ///
  /// Defaults to `true`.
  final bool printRouterLogs;

  /// Whether Riverpod logs should be mirrored to the console.
  ///
  /// Defaults to `true`.
  final bool printRiverpodLogs;

  /// Whether trace lifecycle events should be mirrored to the console.
  ///
  /// Defaults to `true`.
  final bool printTraceLogs;

  /// Whether error-level logs should be mirrored to the console.
  ///
  /// Defaults to `true`.
  final bool printErrorLogs;

  /// Console format used when mirroring logs to the terminal.
  ///
  /// Defaults to [DebugConsolePrintFormat.dev].
  final DebugConsolePrintFormat consolePrintFormat;

  /// Whether console-mirrored logs should use ANSI color codes.
  ///
  /// Applies only to terminal output. In-app UI and exports remain plain text.
  /// Defaults to `true`.
  final bool colorizeConsoleOutput;

  /// Creates an immutable [DebugKitConfig].
  ///
  /// All parameters have safe defaults suitable for a development build.
  const DebugKitConfig({
    this.enabled = true,
    this.maxLogs = 300,
    this.captureAppCallLocation = true,
    this.captureAppStackTrace = false,
    this.navigatorKey,
    this.maxTraces = 50,
    this.maxTraceEventsPerTrace = 200,
    this.slowTraceThreshold = const Duration(seconds: 3),
    this.slowRequestThresholdMs = 500,
    this.groupRepeatedLogs = true,
    this.printToConsole = true,
    this.printManualLogs = true,
    this.printNetworkLogs = true,
    this.printRouterLogs = true,
    this.printRiverpodLogs = true,
    this.printTraceLogs = true,
    this.printErrorLogs = true,
    this.consolePrintFormat = DebugConsolePrintFormat.dev,
    this.colorizeConsoleOutput = true,
  });
}
