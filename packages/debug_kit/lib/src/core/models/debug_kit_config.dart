import 'package:flutter/material.dart';

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
  /// When the store reaches [maxLogs], the oldest entry is evicted before the
  /// newest is added. Defaults to `300`.
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
  });
}
