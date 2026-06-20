import 'package:debug_kit/debug_kit.dart';

/// Internal sanitization helpers for Dio-specific data.
///
/// Thin wrappers around the DebugKit core [DebugLogSanitizer] that handle the
/// Dio-specific types (raw header maps, URL strings) before they reach the
/// core logging path.
///
/// Not part of the public adapter API — used only by [DebugKitDioInterceptor].
class DioLogSanitizerHelpers {
  /// Parses [url] into a [Uri] and masks sensitive query parameter values.
  ///
  /// Delegates to [DebugLogSanitizer.sanitizeUri]. Returns [url] unchanged if
  /// parsing fails (malformed URL).
  ///
  /// Example: `https://api.example.com/users?token=secret` →
  /// `https://api.example.com/users?token=se*****et`
  static String sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return DebugLogSanitizer.sanitizeUri(uri);
    } catch (_) {
      return url;
    }
  }

  /// Sanitizes a Dio header map by masking values for sensitive header names.
  ///
  /// Accepts `Map<String, dynamic>` as returned by Dio's [RequestOptions.headers]
  /// and delegates to [DebugLogSanitizer.sanitizeHeaders].
  ///
  /// Common headers that are masked:
  /// - `Authorization`, `Cookie`, `Set-Cookie`
  /// - `X-Auth-Token`, `X-Api-Key`
  static Map<String, String> sanitizeHeaders(Map<String, dynamic> headers) {
    return DebugLogSanitizer.sanitizeHeaders(headers);
  }

  /// Extracts allowlisted backend correlation IDs from response headers.
  ///
  /// Only captures the first non-empty value for each supported key and
  /// truncates the sanitized value to 64 characters.
  static Map<String, String> extractBackendCorrelationHeaders(
    Map<String, List<String>> headers,
  ) {
    final result = <String, String>{};

    void capture(
      List<String> names,
      String metadataKey,
    ) {
      for (final name in names) {
        final values = headers[name] ?? headers[name.toLowerCase()];
        final value = values == null
            ? null
            : values.cast<String?>().firstWhere(
                  (v) => v != null && v.trim().isNotEmpty,
                  orElse: () => null,
                );
        if (value == null || value.trim().isEmpty) continue;

        final sanitized = DebugLogSanitizer.sanitizeMessage(value.trim());
        result[metadataKey] =
            sanitized.length > 64 ? sanitized.substring(0, 64) : sanitized;
        return;
      }
    }

    capture(['x-request-id', 'request-id'], 'backendRequestId');
    capture(['x-correlation-id'], 'backendCorrelationId');
    capture(['x-trace-id', 'trace-id'], 'backendTraceId');

    return result;
  }
}
