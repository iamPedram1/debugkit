/// Controls how much a Dio request's lifecycle is mirrored to the Flutter
/// console. The in-app Network tab always records the full lifecycle
/// (one entry created on start, updated on response/error) regardless of
/// this setting.
enum DebugKitNetworkConsoleLifecycleMode {
  /// Prints a `started` line on request, then a final result line on
  /// response/error. Two console lines per request. This is the default,
  /// matching prior DebugKit behavior.
  startAndFinish,

  /// Prints only the final result line (success or error). No `started`
  /// line. One console line per request.
  finalOnly,

  /// Prints nothing to the Flutter console for network requests. The
  /// Network tab is still kept live.
  none,
}

/// Configuration for safe optional network previews captured by the Dio adapter.
class DebugKitDioConfig {
  /// Captures sanitized request headers when `true`.
  final bool captureRequestHeaders;

  /// Captures sanitized response headers from a safe allowlist when `true`.
  final bool captureResponseHeaders;

  /// Captures a sanitized request body preview when `true`.
  final bool captureRequestBody;

  /// Captures a sanitized response body preview when `true`.
  final bool captureResponseBody;

  /// Formats JSON payloads with indentation when `true`.
  final bool prettyPrintJson;

  /// Attempts to decode gzip-compressed bodies when `true`.
  final bool decodeGzipBodies;

  /// Maximum length of a body preview in characters.
  final int maxBodyPreviewChars;

  /// Maximum size to inspect before skipping capture entirely.
  final int maxBodyBytes;

  /// Backward-compatible alias for [maxBodyBytes].
  @Deprecated('Use maxBodyBytes instead.')
  final int maxCaptureBytes;

  /// Controls Flutter console mirroring for this interceptor's requests.
  ///
  /// Defaults to [DebugKitNetworkConsoleLifecycleMode.startAndFinish],
  /// preserving prior behavior. The in-app Network tab is unaffected by
  /// this setting — it always creates an entry on start and updates it on
  /// response/error.
  final DebugKitNetworkConsoleLifecycleMode networkConsoleLifecycleMode;

  /// Creates safe preview settings for the Dio adapter.
  ///
  /// Body and header previews are disabled by default. Enable them explicitly
  /// when you want sanitized previews in the Network Inspector.
  const DebugKitDioConfig({
    this.captureRequestHeaders = false,
    this.captureResponseHeaders = false,
    this.captureRequestBody = false,
    this.captureResponseBody = false,
    this.prettyPrintJson = false,
    this.decodeGzipBodies = false,
    this.maxBodyPreviewChars = 1000,
    int? maxBodyBytes,
    @Deprecated('Use maxBodyBytes instead.') int? maxCaptureBytes,
    this.networkConsoleLifecycleMode =
        DebugKitNetworkConsoleLifecycleMode.startAndFinish,
  })  : maxBodyBytes = maxBodyBytes ?? maxCaptureBytes ?? 65536,
        maxCaptureBytes = maxBodyBytes ?? maxCaptureBytes ?? 65536;
}
