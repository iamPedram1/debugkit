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
  })  : maxBodyBytes = maxBodyBytes ?? maxCaptureBytes ?? 65536,
        maxCaptureBytes = maxBodyBytes ?? maxCaptureBytes ?? 65536;
}
