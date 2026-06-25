import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_riverpod/debug_kit_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestCounterNotifier extends Notifier<String> {
  @override
  String build() => 'initial';

  void setValue(String value) {
    state = value;
  }
}

class SensitiveObject {
  @override
  String toString() => 'SensitiveObject(token: secret123)';
}

final addProvider = Provider<String>(
  (ref) => 'ready',
  name: 'authProvider',
);

final unnamedProvider = Provider<String>((ref) => 'ready');

final counterProvider = NotifierProvider<TestCounterNotifier, String>(
  TestCounterNotifier.new,
  name: 'userProvider',
);

final throwingProvider = Provider<String>(
  (ref) {
    throw Exception('test error');
  },
  name: 'errorProvider',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DebugKitController controller;

  setUp(() {
    controller = DebugKitController();
    controller.init(enabled: true, printToConsole: false);
    DebugKit.clearLogs();
    DebugKit.clearTraces();
  });

  tearDown(() {
    DebugKit.clearLogs();
    DebugKit.clearTraces();
  });

  ProviderContainer createContainer(DebugKitRiverpodObserver observer) {
    return ProviderContainer.test(observers: [observer]);
  }

  test('didAddProvider logs provider initialization when enabled', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(logProviderUpdates: true),
    );
    final container = createContainer(observer);

    expect(container.read(addProvider), 'ready');

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, 'Riverpod provider added: authProvider');
    expect(log.metadata?['event_type'], 'provider_add');
    expect(log.metadata?['provider_name'], 'authProvider');
  });

  test('didUpdateProvider logs compact previews when enabled', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        logProviderUpdates: true,
        includeValuePreview: true,
        maxValuePreviewLength: 10,
      ),
    );
    final container = createContainer(observer);

    final notifier = container.read(counterProvider.notifier);
    DebugKit.clearLogs();

    notifier.setValue('very_long_string_value_here');

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, 'Riverpod provider updated: userProvider');
    expect(log.metadata?['event_type'], 'provider_update');
    expect(log.metadata?['value_preview'], 'very_long_...');
  });

  test('watchedProviders filters lifecycle logs but not failures', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        logProviderUpdates: true,
        watchedProviders: {'userProvider'},
      ),
    );
    final container = createContainer(observer);

    final watched = container.read(counterProvider.notifier);
    DebugKit.clearLogs();

    watched.setValue('next');
    expect(controller.store.logs.length, 1);
    expect(controller.store.logs.first.message, contains('userProvider'));

    DebugKit.clearLogs();
    expect(container.read(unnamedProvider), 'ready');
    expect(controller.store.logs.isEmpty, isTrue);

    DebugKit.clearLogs();
    expect(() => container.read(throwingProvider), throwsException);
    expect(controller.store.logs.length, 1);
    expect(controller.store.logs.first.message, contains('errorProvider'));
  });

  test('didDisposeProvider logs provider disposal when enabled', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(logProviderUpdates: true),
    );
    final container = ProviderContainer(observers: [observer]);

    expect(container.read(addProvider), 'ready');
    DebugKit.clearLogs();

    container.dispose();

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, 'Riverpod provider disposed: authProvider');
    expect(log.metadata?['event_type'], 'provider_dispose');
  });

  test('provider failures are logged with trace correlation', () async {
    final observer = DebugKitRiverpodObserver(controller: controller);
    final container = createContainer(observer);

    await controller.traceController.run('auth_flow', () async {
      expect(() => container.read(throwingProvider), throwsException);
    });

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, contains('Riverpod provider failed: errorProvider'));
    expect(log.error, contains('test error'));
    expect(log.source, DebugLogSource.riverpod);
    expect(log.traceId, isNotNull);
    expect(log.traceName, 'auth_flow');
    expect(log.metadata?['event_type'], 'provider_failure');

    final trace = controller.traceStore.traces.first;
    final stateEvents =
        trace.events.where((event) => event.type == DebugTraceEventType.state);
    expect(stateEvents, isNotEmpty);
  });

  test('sensitive values are safely redacted in preview', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        logProviderUpdates: true,
        includeValuePreview: true,
      ),
    );
    final container = createContainer(observer);

    final provider = NotifierProvider<TestCounterNotifier, String>(
      TestCounterNotifier.new,
      name: 'authProvider',
    );

    final notifier = container.read(provider.notifier);
    DebugKit.clearLogs();

    notifier.setValue(SensitiveObject().toString());

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.metadata?['value_preview'], contains('SensitiveObject'));
    expect(log.metadata?['value_preview'], isNot(contains('secret123')));
  });

  test('observer does not throw when provider name is null or disabled', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(logProviderUpdates: true),
    );
    final container = createContainer(observer);

    expect(container.read(unnamedProvider), 'ready');
    expect(controller.store.logs.length, 1);
    expect(controller.store.logs.first.message, contains('UnnamedProvider'));

    controller.init(enabled: false);
    DebugKit.clearLogs();
    expect(() => container.read(throwingProvider), throwsException);
    expect(controller.store.logs.isEmpty, isTrue);
  });

  test('disabled mode records no trace events', () async {
    controller.init(enabled: false);
    final observer = DebugKitRiverpodObserver(controller: controller);
    final container = createContainer(observer);

    expect(() => container.read(throwingProvider), throwsException);
    expect(controller.store.logs.isEmpty, isTrue);
    expect(controller.traceStore.traces.isEmpty, isTrue);
  });
}
