import 'package:debug_kit/debug_kit.dart';

/// Internal sanitization helpers for GoRouter-specific data.
///
/// Not part of the public adapter API — used only by
/// [DebugKitGoRouterObserver].
class GoRouterLogHelpers {
  /// Parses [path] as a URI and masks sensitive query parameter values.
  ///
  /// Delegates to [DebugLogSanitizer.sanitizeUri]. Returns [path] unchanged
  /// when parsing fails (malformed route path).
  ///
  /// Example: `/verify?token=secret&email=user@example.com` →
  /// `/verify?token=se*****et&email=us***om`
  static String sanitizeRoutePath(String path) {
    try {
      final uri = Uri.parse(path);
      return DebugLogSanitizer.sanitizeUri(uri);
    } catch (_) {
      return path; // Fail silently on malformed routes
    }
  }
}
