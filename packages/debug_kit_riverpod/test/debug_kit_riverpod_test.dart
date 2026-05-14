import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_riverpod/debug_kit_riverpod.dart';

ProviderBase<Object?> createProvider(String? name) {
  return Provider<int>((ref) => 0, name: name);
}

class SensitiveObject {
  @override
  String toString() => 'SensitiveObject(token: secret123)';
}

void main() {
  late DebugKitController controller;

  setUp(() {
    controller = DebugKitController();
    controller.init(enabled: true);
  });

  // Since we are mocking ProviderContainer simply to pass it to the observer,
  // we can use a basic ProviderContainer.
  final container = ProviderContainer();

  test('observer logs provider failures', () {
    final observer = DebugKitRiverpodObserver(controller: controller);
    final provider = createProvider('authProvider');

    observer.providerDidFail(
        provider, Exception('test error'), StackTrace.empty, container);

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, contains('Riverpod provider failed: authProvider'));
    expect(log.error, contains('test error'));
    expect(log.source, DebugLogSource.riverpod);
    expect(log.metadata?['event_type'], 'provider_failure');
  });

  test('observer does not log provider updates by default', () {
    final observer = DebugKitRiverpodObserver(controller: controller);
    final provider = createProvider('userProvider');

    observer.didUpdateProvider(provider, null, 'new_value', container);

    expect(controller.store.logs.isEmpty, isTrue);
  });

  test('observer logs provider updates when enabled', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(logProviderUpdates: true),
    );
    final provider = createProvider('userProvider');

    observer.didUpdateProvider(provider, null, 'new_value', container);

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, 'Riverpod provider updated: userProvider');
    expect(log.metadata?['event_type'], 'provider_update');
    expect(log.metadata?['value_preview'], isNull); // disabled by default
  });

  test('watchedProviders filters update logs', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        logProviderUpdates: true,
        watchedProviders: {'userProvider'},
      ),
    );

    final userProvider = createProvider('userProvider');
    final settingsProvider = createProvider('settingsProvider');

    observer.didUpdateProvider(userProvider, null, 'new_value', container);
    observer.didUpdateProvider(settingsProvider, null, 'new_value', container);

    // Only userProvider should be logged
    expect(controller.store.logs.length, 1);
    expect(controller.store.logs.first.message, contains('userProvider'));
  });

  test('provider failures bypass watchedProviders when enabled', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        logProviderUpdates: true,
        watchedProviders: {'userProvider'},
        logProviderFailures: true,
      ),
    );

    final settingsProvider = createProvider('settingsProvider');

    observer.providerDidFail(
        settingsProvider, Exception('error'), StackTrace.empty, container);

    expect(controller.store.logs.length, 1);
    expect(controller.store.logs.first.message, contains('settingsProvider'));
  });

  test('disabled DebugKit logs nothing', () {
    controller.init(enabled: false);
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(logProviderUpdates: true),
    );

    final provider = createProvider('userProvider');
    observer.didUpdateProvider(provider, null, 'new_value', container);
    observer.providerDidFail(
        provider, Exception('error'), StackTrace.empty, container);

    expect(controller.store.logs.isEmpty, isTrue);
  });

  test('value preview is sanitized/truncated when explicitly enabled', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        logProviderUpdates: true,
        includeValuePreview: true,
        maxValuePreviewLength: 10,
      ),
    );

    final provider = createProvider('userProvider');
    observer.didUpdateProvider(
        provider, null, 'very_long_string_value_here', container);

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.metadata?['value_preview'], 'very_long_...');
  });

  test('sensitive values are safely redacted in preview', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        logProviderUpdates: true,
        includeValuePreview: true,
      ),
    );

    final provider = createProvider('authProvider');
    observer.didUpdateProvider(provider, null, SensitiveObject(), container);

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.metadata?['value_preview'], contains('Redacted'));
    expect(log.metadata?['value_preview'], isNot(contains('secret123')));
  });

  test('observer does not throw when provider name is null/unknown', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(logProviderUpdates: true),
    );

    final unnamedProvider = createProvider(null);

    expect(
      () => observer.didUpdateProvider(
          unnamedProvider, null, 'new_value', container),
      returnsNormally,
    );
    expect(
      () => observer.providerDidFail(
          unnamedProvider, Exception(), StackTrace.empty, container),
      returnsNormally,
    );

    expect(controller.store.logs.length, 2);
    expect(controller.store.logs.first.message, contains('UnnamedProvider'));
  });
}
