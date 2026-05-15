import 'package:debug_kit/debug_kit.dart';

/// Internal helpers for sanitizing Dio-specific network data.
class DioLogSanitizerHelpers {
  /// Sanitizes a URL by masking sensitive query parameters.
  static String sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return DebugLogSanitizer.sanitizeUri(uri);
    } catch (_) {
      return url;
    }
  }

  /// Sanitizes headers by masking common sensitive fields.
  static Map<String, String> sanitizeHeaders(Map<String, dynamic> headers) {
    return DebugLogSanitizer.sanitizeHeaders(headers);
  }
}
