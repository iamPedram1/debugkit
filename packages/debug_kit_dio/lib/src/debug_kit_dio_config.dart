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

  /// Maximum length of a body preview in characters.
  final int maxBodyPreviewChars;

  /// Maximum size to inspect before skipping capture entirely.
  final int maxCaptureBytes;

  const DebugKitDioConfig({
    this.captureRequestHeaders = false,
    this.captureResponseHeaders = false,
    this.captureRequestBody = false,
    this.captureResponseBody = false,
    this.maxBodyPreviewChars = 1000,
    this.maxCaptureBytes = 65536,
  });
}
