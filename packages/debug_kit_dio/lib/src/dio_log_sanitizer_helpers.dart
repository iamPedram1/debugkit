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
}
