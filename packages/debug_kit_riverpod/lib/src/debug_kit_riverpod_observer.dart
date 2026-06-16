import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:debug_kit/debug_kit.dart';
import 'debug_kit_riverpod_config.dart';
import 'riverpod_log_helpers.dart';

/// A Riverpod [ProviderObserver] that logs provider failures and optionally
/// state updates to DebugKit.
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
/// - State updates — opt-in via [DebugKitRiverpodConfig.logProviderUpdates].
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
class DebugKitRiverpodObserver extends ProviderObserver {
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
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    if (!config.logProviderFailures) return;

    try {
      if (!_controller.config.enabled) return;

      final providerName =
          RiverpodLogHelpers.sanitizeProviderName(provider.name);

      // Read active trace from current Zone
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

      // Record state event on active trace
      if (traceId != null) {
        _controller.traceController.recordStateEvent(
          message: 'provider failed: $providerName',
          metadata: {
            'provider_name': providerName,
            'event_type': 'provider_failure',
          },
          error: error.toString(),
        );
      }
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
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (!config.logProviderUpdates) return;

    try {
      if (!_controller.config.enabled) return;

      final providerName =
          RiverpodLogHelpers.sanitizeProviderName(provider.name);

      if (config.watchedProviders.isNotEmpty &&
          !config.watchedProviders.contains(providerName)) {
        return;
      }

      final metadata = <String, String>{
        'provider_name': providerName,
        'event_type': 'provider_update',
      };

      if (config.includeValuePreview) {
        metadata['value_preview'] = RiverpodLogHelpers.safeValuePreview(
          newValue,
          config.maxValuePreviewLength,
        );
      }

      // Read active trace from current Zone
      final traceId = _controller.traceController.activeTraceId;
      final traceName = _controller.traceController.activeTraceName;

      _controller.log(
        message: 'Riverpod provider updated: $providerName',
        level: DebugLogLevel.debug,
        source: DebugLogSource.riverpod,
        metadata: metadata,
        traceId: traceId,
        traceName: traceName,
      );
    } catch (_) {
      // Fail silently
    }
  }
}
