import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_go_router/debug_kit_go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DebugKitController controller;
  late DebugKitGoRouterObserver observer;

  setUp(() {
    controller = DebugKitController();
    controller.init(enabled: true);
    observer = DebugKitGoRouterObserver(controller);
  });

  Route<dynamic> createRoute(String? name) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name, arguments: {'extra': 'secret_data'}),
      builder: (_) => const SizedBox(),
    );
  }

  test('push logs navigation entry', () {
    final route = createRoute('/home');
    final prevRoute = createRoute('/splash');

    observer.didPush(route, prevRoute);

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, 'push: /home');
    expect(log.source, DebugLogSource.router);
    expect(log.metadata?['action'], 'push');
    expect(log.metadata?['route_path'], '/home');
    expect(log.metadata?['previous_route_path'], '/splash');

    // Extra should not be logged
    expect(log.message, isNot(contains('secret_data')));
    expect(log.metadata.toString(), isNot(contains('secret_data')));
  });

  test('pop logs navigation entry', () {
    final route = createRoute('/profile');
    final prevRoute = createRoute('/home');

    observer.didPop(route, prevRoute);

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, 'pop: /profile');
    expect(log.metadata?['action'], 'pop');
    expect(log.metadata?['route_path'], '/profile');
    expect(log.metadata?['previous_route_path'], '/home');
  });

  test('replace logs navigation entry', () {
    final newRoute = createRoute('/dashboard');
    final oldRoute = createRoute('/login');

    observer.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, 'replace: /login → /dashboard');
    expect(log.metadata?['action'], 'replace');
  });

  test('remove logs navigation entry', () {
    final route = createRoute('/modal');

    observer.didRemove(route, null);

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, 'remove: /modal');
    expect(log.metadata?['action'], 'remove');
  });

  test('route query params are sanitized', () {
    final route = createRoute('/verify?email=test@example.com&token=secret123');

    observer.didPush(route, null);

    expect(controller.store.logs.length, 1);
    final log = controller.store.logs.first;
    expect(log.message, contains('email='));
    expect(log.message, isNot(contains('test@example.com')));
    expect(log.message, isNot(contains('secret123')));
  });

  test('observer does not throw on null/unnamed routes', () {
    final unnamedRoute = createRoute(null);

    expect(() => observer.didPush(unnamedRoute, null), returnsNormally);

    expect(controller.store.logs.length, 1);
    expect(controller.store.logs.first.message, isNot(contains('unknown')));
    expect(controller.store.logs.first.message, contains('MaterialPageRoute'));
  });

  test('disabled DebugKit does not store navigation logs', () {
    controller.init(enabled: false);

    final route = createRoute('/home');
    observer.didPush(route, null);

    expect(controller.store.logs.isEmpty, isTrue);
  });

  // ---------------------------------------------------------------------------
  // Trace correlation
  // ---------------------------------------------------------------------------
  test('navigation log carries traceId when inside active trace', () async {
    controller.init(enabled: true);

    await controller.traceController.run('nav_flow', () async {
      final route = createRoute('/home');
      observer.didPush(route, null);
    });

    final log = controller.store.logs.first;
    expect(log.traceId, isNotNull);
    expect(log.traceName, 'nav_flow');
  });

  test('navigation log has no traceId when outside any trace', () {
    controller.init(enabled: true);
    final route = createRoute('/home');
    observer.didPush(route, null);

    final log = controller.store.logs.first;
    expect(log.traceId, isNull);
  });

  test('navigation trace event is recorded on active trace', () async {
    controller.init(enabled: true);

    await controller.traceController.run('nav_flow', () async {
      final route = createRoute('/home');
      observer.didPush(route, null);
    });

    final trace = controller.traceStore.traces.first;
    final navEvents = trace.events
        .where((e) => e.type == DebugTraceEventType.navigation)
        .toList();
    expect(navEvents.isNotEmpty, isTrue);
  });

  test('disabled mode: no trace events recorded', () async {
    controller.init(enabled: false);
    final route = createRoute('/home');
    observer.didPush(route, null);
    expect(controller.traceStore.traces.isEmpty, isTrue);
  });
}
