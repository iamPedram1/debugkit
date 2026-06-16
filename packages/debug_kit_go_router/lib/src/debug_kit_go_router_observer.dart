import 'package:flutter/widgets.dart';
import 'package:debug_kit/debug_kit.dart';
import 'go_router_log_helpers.dart';

/// A Navigator observer that logs GoRouter navigation events to DebugKit.
///
/// If navigation occurs inside an active [DebugKit.trace.run] zone, the
/// trace ID and name are automatically attached to the log entry and a
/// navigation trace event is recorded on the active trace.
class DebugKitGoRouterObserver extends NavigatorObserver {
  final DebugKitController? _customController;

  DebugKitGoRouterObserver([this._customController]);

  DebugKitController get _controller =>
      _customController ?? DebugKit.controller;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logEvent('push', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logEvent('pop', route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logEvent('remove', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _logEvent('replace', newRoute, oldRoute);
  }

  void _logEvent(
      String action, Route<dynamic>? route, Route<dynamic>? previousRoute) {
    try {
      if (!_controller.config.enabled) return;

      final routeName = route?.settings.name;
      final prevRouteName = previousRoute?.settings.name;

      if (routeName == null && prevRouteName == null) return;

      final sanitizedRoute = routeName != null
          ? GoRouterLogHelpers.sanitizeRoutePath(routeName)
          : null;
      final sanitizedPrevRoute = prevRouteName != null
          ? GoRouterLogHelpers.sanitizeRoutePath(prevRouteName)
          : null;

      String message;
      if (action == 'replace') {
        message =
            'replace: ${sanitizedPrevRoute ?? 'unknown'} → ${sanitizedRoute ?? 'unknown'}';
      } else if (action == 'pop') {
        message = 'pop: ${sanitizedRoute ?? 'unknown'}';
      } else {
        message = '$action: ${sanitizedRoute ?? 'unknown'}';
      }

      final metadata = <String, String>{
        'action': action,
        if (sanitizedRoute != null) 'route_path': sanitizedRoute,
        if (sanitizedPrevRoute != null)
          'previous_route_path': sanitizedPrevRoute,
      };

      // Capture active trace context
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
      // Fail silently to never break navigation
    }
  }
}
