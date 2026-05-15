import 'package:debug_kit/debug_kit.dart';

/// Internal helpers for sanitizing GoRouter-specific network data.
class GoRouterLogHelpers {
  /// Sanitizes a route path by masking sensitive query parameters.
  static String sanitizeRoutePath(String path) {
    try {
      final uri = Uri.parse(path);
      return DebugLogSanitizer.sanitizeUri(uri);
    } catch (_) {
      return path; // Fail silently on malformed routes
    }
  }
}
