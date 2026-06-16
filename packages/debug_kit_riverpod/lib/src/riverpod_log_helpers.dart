import 'package:debug_kit/debug_kit.dart';

/// Internal helpers for sanitizing Riverpod-specific data before it reaches
/// the DebugKit log store.
///
/// Not part of the public adapter API — used only by
/// [DebugKitRiverpodObserver].
class RiverpodLogHelpers {
  /// Returns a safe, bounded provider name string.
  ///
  /// - Returns `'UnnamedProvider'` when [name] is `null` or empty.
  /// - Truncates names longer than 100 characters and appends `'...'`.
  ///
  /// Prevents accidental huge string dumps if a provider has an unexpectedly
  /// long generated name.
  static String sanitizeProviderName(String? name) {
    if (name == null || name.isEmpty) return 'UnnamedProvider';
    return name.length > 100 ? '${name.substring(0, 100)}...' : name;
  }

  /// Truncates [value] to [maxLength] characters and appends `'...'` when
  /// truncation occurs.
  ///
  /// Returns [value] unchanged when its length is within [maxLength].
  static String truncateValue(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }

  /// Safely converts [value] to a string, passes it through
  /// [DebugLogSanitizer.sanitizeMessage], and truncates to [maxLength].
  ///
  /// When [value] is `null`, returns `'null'`.
  /// When `.toString()` throws, returns `'[Un-stringifyable Object]'` rather
  /// than propagating the exception.
  ///
  /// Used to produce the `'value_preview'` metadata field when
  /// [DebugKitRiverpodConfig.includeValuePreview] is `true`.
  static String safeValuePreview(dynamic value, int maxLength) {
    try {
      if (value == null) return 'null';
      final stringified = value.toString();

      // Pass through core sanitizer to mask any obvious secrets
      final sanitized = DebugLogSanitizer.sanitizeMessage(stringified);

      return truncateValue(sanitized, maxLength);
    } catch (_) {
      return '[Un-stringifyable Object]';
    }
  }
}
