/// Internal helpers for sanitizing GoRouter-specific network data.
class GoRouterLogHelpers {
  /// Sanitizes a route path by masking sensitive query parameters.
  static String sanitizeRoutePath(String path) {
    try {
      final uri = Uri.parse(path);
      if (!uri.hasQuery) return path;

      final params = Map<String, String>.from(uri.queryParameters);
      final keysToSanitize = {
        'token',
        'auth',
        'key',
        'api_key',
        'apikey',
        'secret',
        'password',
        'pass',
        'pwd',
        'access_token',
        'refresh_token',
        'session',
        'sid',
        'email',
        'code',
      };

      var changed = false;
      for (final key in params.keys) {
        if (keysToSanitize.contains(key.toLowerCase())) {
          params[key] = '***';
          changed = true;
        }
      }

      if (!changed) return path;

      return uri.replace(queryParameters: params).toString();
    } catch (_) {
      return path; // Fail silently on malformed routes
    }
  }
}
