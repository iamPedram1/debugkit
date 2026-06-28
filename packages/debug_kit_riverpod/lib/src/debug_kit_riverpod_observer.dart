import 'package:debug_kit/debug_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'debug_kit_riverpod_config.dart';
import 'riverpod_log_helpers.dart';

/// A Riverpod [ProviderObserver] that records provider state events into
/// DebugKit's dedicated State tab.
///
/// By default, provider updates no longer flood the Logs tab. State changes
/// are stored as [DebugStateEvent] objects, and error events can still be
/// mirrored to Logs for visibility.
base class DebugKitRiverpodObserver extends ProviderObserver {
  /// Creates a [DebugKitRiverpodObserver].
  ///
  /// - [controller]: optional override for testing. Leave `null` to use the
  ///   singleton [DebugKit.controller].
  /// - [config]: controls which provider events are recorded and whether any
  ///   should also be mirrored to the Logs tab.
  DebugKitRiverpodObserver({
    DebugKitController? controller,
    this.config = const DebugKitRiverpodConfig(),
  }) : _customController = controller;

  final DebugKitController? _customController;

  /// Configuration for this observer instance.
  final DebugKitRiverpodConfig config;

  DebugKitController get _controller =>
      _customController ?? DebugKit.controller;

  bool _shouldTrackProvider(String providerName) {
    if (config.watchedProviders.isEmpty) return true;
    return config.watchedProviders.contains(providerName);
  }

  String _providerNameFor(Object provider) {
    final dynamic dynamicProvider = provider;
    String? explicitName;
    try {
      explicitName = dynamicProvider.name as String?;
    } catch (_) {
      explicitName = null;
    }

    return RiverpodLogHelpers.resolveProviderName(
      explicitName: explicitName,
      providerString: provider.toString(),
      runtimeTypeName: provider.runtimeType.toString(),
    );
  }

  String _providerTypeFor(Object provider) {
    final raw = provider.runtimeType.toString();
    return RiverpodLogHelpers.sanitizeProviderName(
      raw.contains('<') ? raw.split('<').first : raw,
    );
  }

  String _safePreview(dynamic value) => RiverpodLogHelpers.safeValuePreview(
        value,
        config.maxValuePreviewLength,
        sanitizerConfig: _controller.config.sanitizer,
      );

  void _recordStateEvent({
    required String providerName,
    required String providerType,
    required DebugStateEventType eventType,
    String? previousValuePreview,
    String? nextValuePreview,
    String? diffPreview,
    List<DebugStateDiffEntry> changes = const [],
    Object? error,
    StackTrace? stackTrace,
  }) {
    _controller.recordStateEvent(
      DebugStateEvent(
        id: '',
        timestamp: DateTime.now(),
        source: 'riverpod',
        name: providerName,
        type: providerType,
        eventType: eventType,
        previousValuePreview: previousValuePreview,
        nextValuePreview: nextValuePreview,
        diffPreview: diffPreview,
        changes: changes,
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
        metadata: {
          'provider_name': providerName,
          'provider_type': providerType,
          'event_type': eventType.name,
        },
      ),
    );
  }

  void _mirrorLifecycleLog({
    required String providerName,
    required String providerType,
    required DebugStateEventType eventType,
    String? previousValuePreview,
    String? nextValuePreview,
    String? diffPreview,
    List<DebugStateDiffEntry> changes = const [],
  }) {
    if (!config.mirrorStateChangesToLogs) return;

    final message = switch (eventType) {
      DebugStateEventType.added => 'Riverpod provider added: $providerName',
      DebugStateEventType.updated => 'Riverpod provider updated: $providerName',
      DebugStateEventType.disposed =>
        'Riverpod provider disposed: $providerName',
      DebugStateEventType.error => 'Riverpod provider error: $providerName',
    };

    final metadata = <String, String>{
      'provider_name': providerName,
      'provider_type': providerType,
      'event_type': 'provider_${eventType.name}',
    };

    if (previousValuePreview != null) {
      metadata['previous_value_preview'] = previousValuePreview;
    }
    if (nextValuePreview != null) {
      metadata['next_value_preview'] = nextValuePreview;
    }
    if (diffPreview != null) {
      metadata['diff_preview'] = diffPreview;
    }
    if (changes.isNotEmpty) {
      metadata['changes'] = changes.length.toString();
    }

    _controller.log(
      message: message,
      level: eventType == DebugStateEventType.error
          ? DebugLogLevel.error
          : DebugLogLevel.debug,
      source: DebugLogSource.riverpod,
      metadata: metadata,
    );
  }

  void _mirrorFailureLog({
    required String providerName,
    required String providerType,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (!config.mirrorErrorsToLogs) return;

    _controller.log(
      message: 'Riverpod provider failed: $providerName',
      level: DebugLogLevel.error,
      source: DebugLogSource.riverpod,
      error: error.toString(),
      stackTrace: stackTrace,
      metadata: {
        'provider_name': providerName,
        'provider_type': providerType,
        'event_type': 'provider_failure',
      },
    );
  }

  void _recordTraceFailure({
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

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    try {
      if (!_controller.config.enabled) return;
      final providerName = _providerNameFor(context.provider);
      if (!_shouldTrackProvider(providerName)) return;
      final providerType = _providerTypeFor(context.provider);
      final nextPreview = config.includeValuePreview && value != null
          ? _safePreview(value)
          : null;
      final changes = value == null
          ? const <DebugStateDiffEntry>[]
          : RiverpodLogHelpers.buildStateDiffEntries(
              null,
              value,
              maxDepth: config.maxDiffDepth,
              maxEntries: config.maxDiffEntries,
              maxValuePreviewLength: config.maxValuePreviewLength,
              sanitizerConfig: _controller.config.sanitizer,
            );
      final diffPreview = RiverpodLogHelpers.summarizeChanges(changes);

      if (config.recordProviderAdds) {
        _recordStateEvent(
          providerName: providerName,
          providerType: providerType,
          eventType: DebugStateEventType.added,
          nextValuePreview: nextPreview,
          diffPreview: diffPreview,
          changes: changes,
        );
      }
      _mirrorLifecycleLog(
        providerName: providerName,
        providerType: providerType,
        eventType: DebugStateEventType.added,
        nextValuePreview: nextPreview,
        diffPreview: diffPreview,
        changes: changes,
      );
    } catch (_) {
      // Fail silently.
    }
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    try {
      if (!_controller.config.enabled) return;
      final providerName = _providerNameFor(context.provider);
      if (!_shouldTrackProvider(providerName)) return;
      final providerType = _providerTypeFor(context.provider);

      if (config.recordProviderDisposals) {
        _recordStateEvent(
          providerName: providerName,
          providerType: providerType,
          eventType: DebugStateEventType.disposed,
        );
      }
      _mirrorLifecycleLog(
        providerName: providerName,
        providerType: providerType,
        eventType: DebugStateEventType.disposed,
      );
    } catch (_) {
      // Fail silently.
    }
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    try {
      if (!_controller.config.enabled) return;
      final providerName = _providerNameFor(context.provider);
      if (!_shouldTrackProvider(providerName)) return;
      final providerType = _providerTypeFor(context.provider);
      final previousPreview =
          config.includeValuePreview && previousValue != null
              ? _safePreview(previousValue)
              : null;
      final nextPreview = config.includeValuePreview && newValue != null
          ? _safePreview(newValue)
          : null;
      final changes = RiverpodLogHelpers.buildStateDiffEntries(
        previousValue,
        newValue,
        maxDepth: config.maxDiffDepth,
        maxEntries: config.maxDiffEntries,
        maxValuePreviewLength: config.maxValuePreviewLength,
        sanitizerConfig: _controller.config.sanitizer,
      );
      final diffPreview = RiverpodLogHelpers.summarizeChanges(changes);

      if (config.recordProviderUpdates) {
        _recordStateEvent(
          providerName: providerName,
          providerType: providerType,
          eventType: DebugStateEventType.updated,
          previousValuePreview: previousPreview,
          nextValuePreview: nextPreview,
          diffPreview: diffPreview,
          changes: changes,
        );
      }
      _mirrorLifecycleLog(
        providerName: providerName,
        providerType: providerType,
        eventType: DebugStateEventType.updated,
        previousValuePreview: previousPreview,
        nextValuePreview: nextPreview,
        diffPreview: diffPreview,
        changes: changes,
      );
    } catch (_) {
      // Fail silently.
    }
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    try {
      if (!_controller.config.enabled) return;
      final providerName = _providerNameFor(context.provider);
      final providerType = _providerTypeFor(context.provider);

      if (config.recordProviderErrors) {
        _recordStateEvent(
          providerName: providerName,
          providerType: providerType,
          eventType: DebugStateEventType.error,
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (config.mirrorErrorsToLogs) {
        _mirrorFailureLog(
          providerName: providerName,
          providerType: providerType,
          error: error,
          stackTrace: stackTrace,
        );
      }
      _recordTraceFailure(providerName: providerName, error: error);
    } catch (_) {
      // Fail silently.
    }
  }
}
