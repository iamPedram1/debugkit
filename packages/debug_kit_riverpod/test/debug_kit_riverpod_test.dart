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

class NestedMapNotifier extends Notifier<Map<String, Object?>> {
  @override
  Map<String, Object?> build() {
    return const <String, Object?>{
      'profile': <String, Object?>{
        'metadata': <String, Object?>{
          'status': 'idle',
          'theme': 'dark',
        },
      },
    };
  }

  void updateStatus(String status) {
    final profile = Map<String, Object?>.from(
      state['profile'] as Map<String, Object?>,
    );
    final metadata = Map<String, Object?>.from(
      profile['metadata'] as Map<String, Object?>,
    );
    metadata['status'] = status;
    profile['metadata'] = metadata;
    state = <String, Object?>{
      ...state,
      'profile': profile,
    };
  }
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

final nestedMapProvider =
    NotifierProvider<NestedMapNotifier, Map<String, Object?>>(
  NestedMapNotifier.new,
  name: 'nestedProfileProvider',
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
    controller.init(enabled: true, printToConsole: false, maxStateEvents: 8);
    DebugKit.clearLogs();
    DebugKit.clearStateEvents();
    DebugKit.clearTraces();
  });

  tearDown(() {
    DebugKit.clearLogs();
    DebugKit.clearStateEvents();
    DebugKit.clearTraces();
  });

  ProviderContainer createContainer(DebugKitRiverpodObserver observer) {
    return ProviderContainer.test(observers: [observer]);
  }

  test('didAddProvider records a state event by default', () {
    final observer = DebugKitRiverpodObserver(controller: controller);
    final container = createContainer(observer);

    expect(container.read(addProvider), 'ready');

    final stateEvents = controller.stateStore.events
        .where((event) => event.eventType == DebugStateEventType.added)
        .toList();
    expect(stateEvents, isNotEmpty);
    final event = stateEvents.first;
    expect(event.eventType, DebugStateEventType.added);
    expect(event.name, 'authProvider');
    expect(event.metadata?['event_type'], 'added');
    expect(controller.store.logs, isEmpty);
  });

  test('didUpdateProvider records compact previews when enabled', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        includeValuePreview: true,
        maxValuePreviewLength: 10,
      ),
    );
    final container = createContainer(observer);

    final notifier = container.read(counterProvider.notifier);
    DebugKit.clearStateEvents();

    notifier.setValue('very_long_string_value_here');

    expect(controller.stateStore.events.length, 1);
    final event = controller.stateStore.events.first;
    expect(event.eventType, DebugStateEventType.updated);
    expect(event.name, 'userProvider');
    expect(event.previousValuePreview, 'initial');
    expect(event.nextValuePreview, 'very_long_...');
    expect(event.changes, hasLength(1));
    expect(event.changes.single.path, r'$');
    expect(event.changes.single.type, DebugStateDiffType.changed);
    expect(event.diffPreview, contains('changed'));
    expect(controller.store.logs, isEmpty);
  });

  test('respects disabled sanitizer config for previews', () {
    controller.init(
      enabled: true,
      printToConsole: false,
      maxStateEvents: 8,
      sanitizer: const DebugKitSanitizerConfig(
        dangerouslyDisableSanitizer: true,
      ),
    );

    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        includeValuePreview: true,
        maxValuePreviewLength: 120,
      ),
    );
    final container = createContainer(observer);
    final notifier = container.read(counterProvider.notifier);
    DebugKit.clearStateEvents();

    notifier.setValue('SensitiveObject(token: secret123)');

    expect(controller.stateStore.events.length, 1);
    final event = controller.stateStore.events.first;
    expect(
        event.nextValuePreview, contains('SensitiveObject(token: secret123)'));
    expect(event.changes.single.nextValuePreview,
        contains('SensitiveObject(token: secret123)'));
  });

  test('nested map updates record structured changed paths', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        includeValuePreview: true,
      ),
    );
    final container = createContainer(observer);
    final notifier = container.read(nestedMapProvider.notifier);
    DebugKit.clearStateEvents();

    notifier.updateStatus('active');

    expect(controller.stateStore.events.length, 1);
    final event = controller.stateStore.events.first;
    expect(event.name, 'nestedProfileProvider');
    expect(event.changes, hasLength(1));
    expect(event.changes.single.path, 'profile.metadata.status');
    expect(event.changes.single.previousValuePreview, 'idle');
    expect(event.changes.single.nextValuePreview, 'active');
    expect(event.diffPreview, contains('profile.metadata.status'));
    expect(controller.store.logs, isEmpty);
  });

  test('watchedProviders filters state events but not failures', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        watchedProviders: {'userProvider'},
      ),
    );
    final container = createContainer(observer);

    final watched = container.read(counterProvider.notifier);
    DebugKit.clearStateEvents();

    watched.setValue('next');
    expect(controller.stateStore.events.length, 1);
    expect(controller.stateStore.events.first.name, 'userProvider');

    DebugKit.clearStateEvents();
    expect(container.read(unnamedProvider), 'ready');
    expect(controller.stateStore.events, isEmpty);

    DebugKit.clearLogs();
    expect(() => container.read(throwingProvider), throwsException);
    expect(controller.stateStore.events.length, 1);
    expect(controller.stateStore.events.first.eventType,
        DebugStateEventType.error);
    expect(controller.store.logs.length, 1);
    expect(controller.store.logs.first.message, contains('errorProvider'));
  });

  test('didDisposeProvider records a state event', () {
    final observer = DebugKitRiverpodObserver(controller: controller);
    final container = ProviderContainer(observers: [observer]);

    expect(container.read(addProvider), 'ready');
    DebugKit.clearStateEvents();

    container.dispose();

    expect(controller.stateStore.events.length, 1);
    final event = controller.stateStore.events.first;
    expect(event.eventType, DebugStateEventType.disposed);
    expect(event.name, 'authProvider');
    expect(controller.store.logs, isEmpty);
  });

  test('provider failures record state events and logs with trace correlation',
      () async {
    final observer = DebugKitRiverpodObserver(controller: controller);
    final container = createContainer(observer);

    await controller.traceController.run('auth_flow', () async {
      expect(() => container.read(throwingProvider), throwsException);
    });

    expect(controller.stateStore.events.length, 2);
    expect(
      controller.stateStore.events.map((event) => event.eventType),
      containsAll(<DebugStateEventType>[
        DebugStateEventType.added,
        DebugStateEventType.error,
      ]),
    );
    final errorEvent = controller.stateStore.events.firstWhere(
      (event) => event.eventType == DebugStateEventType.error,
    );
    expect(errorEvent.error, contains('test error'));
    expect(errorEvent.name, 'errorProvider');

    expect(controller.store.logs, isNotEmpty);
    expect(
      controller.store.logs
          .where((log) => log.message.contains('Riverpod provider failed'))
          .length,
      greaterThanOrEqualTo(1),
    );
    final log = controller.store.logs.firstWhere(
      (log) => log.message.contains('Riverpod provider failed'),
    );
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

  test('mirrorStateChangesToLogs keeps the old noisy lifecycle logs', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        mirrorStateChangesToLogs: true,
        includeValuePreview: true,
      ),
    );
    final container = createContainer(observer);

    expect(container.read(addProvider), 'ready');
    expect(controller.store.logs.length, 1);
    expect(controller.store.logs.first.message,
        contains('Riverpod provider added'));
  });

  test('sensitive values are safely redacted in preview', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(
        includeValuePreview: true,
      ),
    );
    final provider = NotifierProvider<TestCounterNotifier, String>(
      TestCounterNotifier.new,
      name: 'authProvider',
    );
    final container = createContainer(observer);
    final notifier = container.read(provider.notifier);
    DebugKit.clearStateEvents();

    notifier.setValue(SensitiveObject().toString());

    expect(controller.stateStore.events.length, 1);
    final event = controller.stateStore.events.first;
    expect(event.nextValuePreview, contains('SensitiveObject'));
    expect(event.nextValuePreview, isNot(contains('secret123')));
    expect(event.changes.single.nextValuePreview, isNot(contains('secret123')));
  });

  test('observer does not throw when provider name is null or disabled', () {
    final observer = DebugKitRiverpodObserver(
      controller: controller,
      config: const DebugKitRiverpodConfig(),
    );
    final container = createContainer(observer);

    expect(container.read(unnamedProvider), 'ready');
    expect(controller.stateStore.events.length, 1);
    expect(controller.stateStore.events.first.name, isNot('UnnamedProvider'));
    expect(controller.stateStore.events.first.name, contains('Provider'));

    controller.init(enabled: false);
    DebugKit.clearLogs();
    DebugKit.clearStateEvents();
    expect(() => container.read(throwingProvider), throwsException);
    expect(controller.store.logs, isEmpty);
    expect(controller.stateStore.events, isEmpty);
  });

  test('disabled mode records no state events or logs', () async {
    controller.init(enabled: false);
    final observer = DebugKitRiverpodObserver(controller: controller);
    final container = createContainer(observer);

    expect(() => container.read(throwingProvider), throwsException);
    expect(controller.store.logs, isEmpty);
    expect(controller.stateStore.events, isEmpty);
    expect(controller.traceStore.traces, isEmpty);
  });
}
