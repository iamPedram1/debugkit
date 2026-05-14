/// Internal helpers for sanitizing Riverpod state data.
class RiverpodLogHelpers {
  /// Safely sanitizes a provider name to prevent huge string dumps.
  static String sanitizeProviderName(String? name) {
    if (name == null || name.isEmpty) return 'UnnamedProvider';
    return name.length > 100 ? '${name.substring(0, 100)}...' : name;
  }

  /// Truncates a value preview string.
  static String truncateValue(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }

  /// Safely gets a value preview from a generic object without crashing.
  static String safeValuePreview(dynamic value, int maxLength) {
    try {
      if (value == null) return 'null';
      final stringified = value.toString();

      // Simple rudimentary masking for obvious secrets that might be printed
      // from models that don't override toString securely.
      final lowered = stringified.toLowerCase();
      if (lowered.contains('token') ||
          lowered.contains('password') ||
          lowered.contains('secret') ||
          lowered.contains('api_key')) {
        return '[Redacted / Possible sensitive data in toString()]';
      }

      return truncateValue(stringified, maxLength);
    } catch (_) {
      return '[Un-stringifyable Object]';
    }
  }
}
