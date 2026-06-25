import 'package:debug_kit/debug_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'debug_kit_riverpod_config.dart';
import 'riverpod_log_helpers.dart';

/// A Riverpod [ProviderObserver] that logs provider failures and optionally
/// provider lifecycle events to DebugKit.
///
/// Add an instance to your [ProviderScope] observers:
///
/// ```dart
/// ProviderScope(
///   observers: [
///     DebugKitRiverpodObserver(),
///   ],
///   child: MyApp(),
/// )
/// ```
///
/// Customize behavior with [DebugKitRiverpodConfig]:
///
/// ```dart
/// DebugKitRiverpodObserver(
///   config: DebugKitRiverpodConfig(
///     logProviderUpdates: true,
///     watchedProviders: {'authProvider'},
///     includeValuePreview: true,
///   ),
/// )
/// ```
///
/// **What is logged by default:**
/// - Provider failures (exceptions thrown inside providers).
///
/// **What is NOT logged by default:**
/// - Provider lifecycle events — opt-in via [DebugKitRiverpodConfig.logProviderUpdates].
/// - Provider state objects — never stringified unless
///   [DebugKitRiverpodConfig.includeValuePreview] is `true`.
///
/// **Trace correlation:** provider failures that occur inside an active
/// [DebugKit.trace.run] zone automatically carry [DebugLogEntry.traceId] and
/// a corresponding [DebugTraceEventType.state] event is recorded on the
/// active trace.
///
/// The observer never throws — all logging is wrapped in `try/catch` so it
/// can never interrupt state management.
base class DebugKitRiverpodObserver extends ProviderObserver {
  /// Creates a [DebugKitRiverpodObserver].
  ///
  /// - [controller]: optional override for testing. Leave `null` to use the
  ///   singleton [DebugKit.controller].
  /// - [config]: controls which events are logged and how verbose they are.
  DebugKitRiverpodObserver({
    DebugKitController? controller,
    this.config = const DebugKitRiverpodConfig(),
  }) : _customController = controller;

  final DebugKitController? _customController;

  /// Configuration for this observer instance.
  final DebugKitRiverpodConfig config;

  DebugKitController get _controller =>
      _customController ?? DebugKit.controller;

  bool _shouldLogProvider(String providerName) {
    if (config.watchedProviders.isEmpty) return true;
    return config.watchedProviders.contains(providerName);
  }

  void _logProviderLifecycleEvent({
    required String providerName,
    required String eventType,
    required String message,
    Object? value,
  }) {
    final metadata = <String, String>{
      'provider_name': providerName,
      'event_type': eventType,
    };

    if (config.includeValuePreview && value != null) {
      metadata['value_preview'] = RiverpodLogHelpers.safeValuePreview(
        value,
        config.maxValuePreviewLength,
      );
    }

    final traceId = _controller.traceController.activeTraceId;
    final traceName = _controller.traceController.activeTraceName;

    _controller.log(
      message: message,
      level: DebugLogLevel.debug,
      source: DebugLogSource.riverpod,
      metadata: metadata,
      traceId: traceId,
      traceName: traceName,
    );
  }

  String _providerNameFor(Object provider) =>
      RiverpodLogHelpers.sanitizeProviderName(
        (provider as dynamic).name as String?,
      );

  void _recordFailureStateEvent({
    required String providerName,
    required Object error,
  }) {
    final traceId = _controller.traceController.activeTraceId;
    if (traceId == null) return;

    _controller.traceController.recordStateEvent(
      message: 'provider failed: $providerName',
      metadata: {
        'provider_name': providerName,
        'event_type': 'provider_failure',
      },
      error: error.toString(),
    );
  }

  void _logFailure({
    required String providerName,
    required Object error,
    required StackTrace stackTrace,
  }) {
    final traceId = _controller.traceController.activeTraceId;
    final traceName = _controller.traceController.activeTraceName;

    _controller.log(
      message: 'Riverpod provider failed: $providerName',
      level: DebugLogLevel.error,
      source: DebugLogSource.riverpod,
      error: error.toString(),
      stackTrace: stackTrace,
      metadata: {
        'provider_name': providerName,
        'event_type': 'provider_failure',
      },
      traceId: traceId,
      traceName: traceName,
    );
    _recordFailureStateEvent(providerName: providerName, error: error);
  }

  /// Called by Riverpod whenever a provider is initialized.
  ///
  /// When [DebugKitRiverpodConfig.logProviderUpdates] is `true`, logs a
  /// compact debug entry for the provider's initial state.
  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    if (!config.logProviderUpdates) return;

    try {
      if (!_controller.config.enabled) return;

      final providerName = _providerNameFor(context.provider);
      if (!_shouldLogProvider(providerName)) return;

      _logProviderLifecycleEvent(
        providerName: providerName,
        eventType: 'provider_add',
        message: 'Riverpod provider added: $providerName',
        value: value,
      );
    } catch (_) {
      // Fail silently
    }
  }

  /// Called by Riverpod whenever a provider is disposed.
  ///
  /// Uses the same update logging gate as state changes so the adapter keeps
  /// a compact default footprint.
  @override
  void didDisposeProvider(ProviderObserverContext context) {
    if (!config.logProviderUpdates) return;

    try {
      if (!_controller.config.enabled) return;

      final providerName = _providerNameFor(context.provider);
      if (!_shouldLogProvider(providerName)) return;

      _logProviderLifecycleEvent(
        providerName: providerName,
        eventType: 'provider_dispose',
        message: 'Riverpod provider disposed: $providerName',
      );
    } catch (_) {
      // Fail silently
    }
  }

  /// Called by Riverpod whenever a provider throws an unhandled exception.
  ///
  /// Logs a [DebugLogLevel.error] entry with:
  /// - The sanitized provider name.
  /// - The error string.
  /// - The stack trace (trimmed to 25 lines).
  /// - `event_type: 'provider_failure'` metadata.
  ///
  /// Also records a [DebugTraceEventType.state] event on the active trace
  /// when [DebugKitRiverpodConfig.logProviderFailures] is `true` (default).
  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!config.logProviderFailures) return;

    try {
      if (!_controller.config.enabled) return;

      final providerName = _providerNameFor(context.provider);

      _logFailure(
        providerName: providerName,
        error: error,
        stackTrace: stackTrace,
      );
    } catch (_) {
      // Fail silently
    }
  }

  /// Called by Riverpod whenever a provider updates its state.
  ///
  /// Skipped entirely unless [DebugKitRiverpodConfig.logProviderUpdates] is
  /// `true`. Also respects [DebugKitRiverpodConfig.watchedProviders] — when
  /// non-empty, only listed provider names emit update logs.
  ///
  /// Logs a [DebugLogLevel.debug] entry with:
  /// - The sanitized provider name.
  /// - `event_type: 'provider_update'` metadata.
  /// - An optional sanitized value preview when
  ///   [DebugKitRiverpodConfig.includeValuePreview] is `true`.
  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (!config.logProviderUpdates) return;

    try {
      if (!_controller.config.enabled) return;

      final providerName = _providerNameFor(context.provider);
      if (!_shouldLogProvider(providerName)) return;

      _logProviderLifecycleEvent(
        providerName: providerName,
        eventType: 'provider_update',
        message: 'Riverpod provider updated: $providerName',
        value: newValue,
      );
    } catch (_) {
      // Fail silently
    }
  }
}
