/// Internal helpers for sanitizing Dio-specific network data.
class DioLogSanitizerHelpers {
  /// Sanitizes a URL by masking sensitive query parameters.
  static String sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasQuery) return url;

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
      };

      var changed = false;
      for (final key in params.keys) {
        if (keysToSanitize.contains(key.toLowerCase())) {
          params[key] = '***';
          changed = true;
        }
      }

      if (!changed) return url;

      return uri.replace(queryParameters: params).toString();
    } catch (_) {
      return url;
    }
  }

  /// Sanitizes headers by masking common sensitive fields.
  static Map<String, String> sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, String>{};
    final keysToSanitize = {
      'authorization',
      'cookie',
      'set-cookie',
      'x-api-key',
      'x-auth-token',
      'proxy-authorization',
    };

    headers.forEach((key, value) {
      if (keysToSanitize.contains(key.toLowerCase())) {
        sanitized[key] = '***';
      } else {
        sanitized[key] = value?.toString() ?? '';
      }
    });

    return sanitized;
  }
}
