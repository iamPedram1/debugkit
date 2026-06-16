import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:debug_kit/debug_kit.dart';
import 'debug_kit_riverpod_config.dart';
import 'riverpod_log_helpers.dart';

/// A Riverpod ProviderObserver that logs provider failures and updates to DebugKit.
///
/// If a provider failure occurs inside an active [DebugKit.trace.run] zone,
/// the trace ID and name are automatically attached to the log entry and a
/// state trace event is recorded on the active trace.
class DebugKitRiverpodObserver extends ProviderObserver {
  DebugKitRiverpodObserver({
    DebugKitController? controller,
    this.config = const DebugKitRiverpodConfig(),
  }) : _customController = controller;

  final DebugKitController? _customController;
  final DebugKitRiverpodConfig config;

  DebugKitController get _controller =>
      _customController ?? DebugKit.controller;

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

      // Capture active trace context
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

      // Capture active trace context
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
