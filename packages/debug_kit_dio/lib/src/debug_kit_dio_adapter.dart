import 'package:dio/dio.dart';
import 'package:debug_kit/debug_kit.dart';
import 'debug_kit_dio_config.dart';
import 'debug_kit_dio_interceptor.dart';

/// A [DebugKitAdapter] that integrates Dio network observability.
///
/// Pass an instance to [DebugKit.init] to automatically log all Dio HTTP
/// transactions — requests, responses, and errors — into the DebugKit console:
///
/// ```dart
/// final dio = Dio();
///
/// DebugKit.init(
///   enabled: true,
///   adapters: [DebugKitDioAdapter(dio)],
/// );
/// ```
///
/// Alternatively, add the interceptor directly to an existing Dio instance:
///
/// ```dart
/// dio.interceptors.add(DebugKitDioInterceptor(DebugKit.controller));
/// ```
///
/// **What is logged:**
/// - HTTP method and sanitized URL (sensitive query parameters masked).
/// - Request path, phase, response status code, and round-trip duration.
/// - Safe backend correlation IDs from allowlisted response headers.
/// - Error type and message on failure.
/// - `'cancelled'` status for Dio cancel exceptions.
///
/// **What is NOT logged:**
/// - Request bodies — never captured to prevent PII leakage.
/// - Response bodies — never captured by default.
/// - Binary or multipart payloads — always ignored.
/// - Authorization, Cookie, Set-Cookie, and arbitrary headers — never stored.
///
/// Optional safe previews can be enabled through [DebugKitDioConfig].
/// Request headers are sanitized when captured. Response headers are captured
/// only from a safe allowlist. Request and response body previews remain opt-in.
///
/// **Trace correlation:** requests made inside an active [DebugKit.trace.run]
/// zone automatically carry [DebugLogEntry.traceId] and a corresponding
/// [DebugTraceEventType.network] event is recorded on the active trace.
class DebugKitDioAdapter extends DebugKitAdapter {
  /// The [Dio] instance whose network traffic will be logged.
  final Dio dio;

  /// Safe opt-in capture settings for headers and body previews.
  final DebugKitDioConfig config;

  DebugKitDioInterceptor? _interceptor;

  /// Creates a [DebugKitDioAdapter] for the given [dio] instance.
  DebugKitDioAdapter(this.dio, {this.config = const DebugKitDioConfig()});

  /// Attaches a [DebugKitDioInterceptor] to [dio].
  ///
  /// Guards against duplicate attachment — calling [attach] a second time
  /// without an intervening [dispose] is a no-op.
  @override
  void attach(DebugKitController controller) {
    if (_interceptor != null) return;

    _interceptor = DebugKitDioInterceptor(controller, config: config);
    dio.interceptors.add(_interceptor!);
  }

  /// Removes the [DebugKitDioInterceptor] from [dio] and releases resources.
  ///
  /// Safe to call even if [attach] was never called.
  @override
  void dispose() {
    if (_interceptor != null) {
      dio.interceptors.remove(_interceptor);
      _interceptor = null;
    }
  }
}
