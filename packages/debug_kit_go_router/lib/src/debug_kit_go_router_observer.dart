import 'package:flutter/widgets.dart';
import 'package:debug_kit/debug_kit.dart';
import 'go_router_log_helpers.dart';

/// A Flutter [NavigatorObserver] that logs GoRouter navigation events to
/// DebugKit.
///
/// Add an instance to your [GoRouter] configuration:
///
/// ```dart
/// GoRouter(
///   observers: [DebugKitGoRouterObserver()],
///   routes: [...],
/// )
/// ```
///
/// **What is logged:**
/// - Navigation action: `push`, `pop`, `replace`, `remove`.
/// - Sanitized route path (sensitive query parameters masked).
/// - Previous route path where applicable.
///
/// **What is NOT logged:**
/// - Route `extra` objects — explicitly ignored to prevent PII leakage and
///   to avoid stringifying large payloads.
/// - Sensitive query parameter values — masked before storage.
///
/// **Trace correlation:** navigation events that occur inside an active
/// [DebugKit.trace.run] zone automatically carry [DebugLogEntry.traceId] and
/// a corresponding [DebugTraceEventType.navigation] event is recorded on the
/// active trace.
///
/// The observer never throws — all logging is wrapped in `try/catch` so it
/// can never interrupt navigation.
class DebugKitGoRouterObserver extends NavigatorObserver {
  /// Optional custom [DebugKitController].
  ///
  /// When `null` (the default), the singleton [DebugKit.controller] is used.
  /// Pass a custom controller only in tests that need to inspect the store in
  /// isolation.
  final DebugKitController? _customController;

  /// Creates a [DebugKitGoRouterObserver].
  ///
  /// - [_customController]: optional override for testing. Leave `null` in
  ///   production code.
  DebugKitGoRouterObserver([this._customController]);

  DebugKitController get _controller =>
      _customController ?? DebugKit.controller;

  /// Called by the [Navigator] after a route has been pushed onto the stack.
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logEvent('push', route, previousRoute);
  }

  /// Called by the [Navigator] after a route has been popped from the stack.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logEvent('pop', route, previousRoute);
  }

  /// Called by the [Navigator] after a route has been removed from the stack.
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logEvent('remove', route, previousRoute);
  }

  /// Called by the [Navigator] after a route has replaced another route.
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _logEvent('replace', newRoute, oldRoute);
  }

  /// Core logging implementation shared by all observer callbacks.
  ///
  /// Extracts route names, sanitizes paths, builds a human-readable message,
  /// and calls [DebugKitController.log]. Also records a navigation trace event
  /// when an active trace is running in the current Zone.
  ///
  /// Silently returns when:
  /// - DebugKit is disabled.
  /// - Both [route] and [previousRoute] have no name (unnamed routes).
  void _logEvent(
    String action,
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    try {
      if (!_controller.config.enabled) return;

      final routeName = route?.settings.name;
      final prevRouteName = previousRoute?.settings.name;
      final routeType = route?.runtimeType.toString();
      final prevRouteType = previousRoute?.runtimeType.toString();

      final routeLabel = GoRouterLogHelpers.routeLabel(
        routeName: routeName,
        routeType: routeType ?? '',
      );
      final prevRouteLabel = GoRouterLogHelpers.routeLabel(
        routeName: prevRouteName,
        routeType: prevRouteType ?? '',
      );
      final safeRouteName = routeName?.trim() ?? '';
      final safePrevRouteName = prevRouteName?.trim() ?? '';
      final hasRouteName = routeName != null && routeName.trim().isNotEmpty;
      final hasPrevRouteName =
          prevRouteName != null && prevRouteName.trim().isNotEmpty;

      if (routeLabel == 'UnnamedRoute' && prevRouteLabel == 'UnnamedRoute') {
        return;
      }

      final message = switch (action) {
        'replace' => 'replace: $prevRouteLabel → $routeLabel',
        'pop' => 'pop: $routeLabel',
        _ => '$action: $routeLabel',
      };

      final metadata = <String, String>{
        'action': action,
        'route_label': routeLabel,
        'route_type': routeType ?? '',
        if (hasRouteName) 'route_name': safeRouteName,
        if (hasRouteName)
          'route_path': GoRouterLogHelpers.sanitizeRoutePath(safeRouteName),
        if (hasPrevRouteName) 'previous_route_name': safePrevRouteName,
        'previous_route_label': prevRouteLabel,
        'previous_route_type': prevRouteType ?? '',
        if (hasPrevRouteName)
          'previous_route_path':
              GoRouterLogHelpers.sanitizeRoutePath(safePrevRouteName),
      };

      // Read active trace from current Zone
      final traceId = _controller.traceController.activeTraceId;
      final traceName = _controller.traceController.activeTraceName;

      _controller.log(
        message: message,
        level: DebugLogLevel.info,
        source: DebugLogSource.router,
        metadata: metadata,
        traceId: traceId,
        traceName: traceName,
      );

      // Record navigation event on active trace
      if (traceId != null) {
        _controller.traceController.recordNavigationEvent(
          message: message,
          metadata: metadata,
        );
      }
    } catch (_) {
      // Fail silently — never interrupt navigation
    }
  }
}
