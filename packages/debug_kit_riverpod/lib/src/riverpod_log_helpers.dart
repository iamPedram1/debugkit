import 'package:debug_kit/debug_kit.dart';

/// Internal helpers for sanitizing Riverpod-specific data before it reaches
/// the DebugKit log store.
///
/// Not part of the public adapter API - used only by
/// [DebugKitRiverpodObserver].
class RiverpodLogHelpers {
  /// Resolves a readable provider name from Riverpod metadata.
  ///
  /// Preference order:
  /// 1. explicit provider name
  /// 2. cleaned `toString()` value
  /// 3. provider runtime type
  /// 4. `UnnamedProvider` as a last resort
  static String resolveProviderName({
    String? explicitName,
    required String providerString,
    required String runtimeTypeName,
  }) {
    final explicit = _cleanName(explicitName);
    if (explicit != null) return explicit;

    final fromString = _cleanName(_cleanProviderString(providerString));
    if (fromString != null) return fromString;

    final fromType = _cleanName(runtimeTypeName);
    if (fromType != null) return fromType;

    return 'UnnamedProvider';
  }

  /// Builds bounded structured diffs for Riverpod state updates.
  static List<DebugStateDiffEntry> buildStateDiffEntries(
    dynamic previousValue,
    dynamic nextValue, {
    required int maxDepth,
    required int maxEntries,
    required int maxValuePreviewLength,
    required DebugKitSanitizerConfig sanitizerConfig,
  }) {
    try {
      return DebugStateDiffBuilder.build(
        previousValue,
        nextValue,
        maxDepth: maxDepth,
        maxEntries: maxEntries,
        maxValuePreviewLength: maxValuePreviewLength,
        sanitizerConfig: sanitizerConfig,
      );
    } catch (_) {
      return const [];
    }
  }

  /// Summarizes structured changes for concise list and log previews.
  static String summarizeChanges(List<DebugStateDiffEntry> changes) {
    if (changes.isEmpty) return 'updated';

    final first = changes.first;
    final path = first.path == r'$' ? 'state' : first.path;
    if (changes.length == 1) {
      return '$path ${first.type.label.toLowerCase()}';
    }

    return '$path ${first.type.label.toLowerCase()} · ${changes.length} changes';
  }

  /// Returns a safe, bounded provider name string.
  ///
  /// - Returns `'UnnamedProvider'` when [name] is `null` or empty.
  /// - Truncates names longer than 100 characters and appends `'...'`.
  ///
  /// Prevents accidental huge string dumps if a provider has an unexpectedly
  /// long generated name.
  static String sanitizeProviderName(String? name) {
    return _cleanName(name) ?? 'UnnamedProvider';
  }

  static String? _cleanName(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > 100 ? '${trimmed.substring(0, 100)}...' : trimmed;
  }

  static String _cleanProviderString(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final withoutHash = trimmed.replaceFirst(RegExp(r'#\w+$'), '');
    return withoutHash.trim();
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
  static String safeValuePreview(
    dynamic value,
    int maxLength, {
    DebugKitSanitizerConfig sanitizerConfig = const DebugKitSanitizerConfig(),
  }) {
    try {
      if (value == null) return 'null';
      final stringified = value.toString();

      if (sanitizerConfig.dangerouslyDisableSanitizer) {
        return stringified;
      }

      // Pass through core sanitizer to mask any obvious secrets.
      final sanitized = DebugLogSanitizer.sanitizeMessage(
        stringified,
        config: sanitizerConfig,
      );

      return truncateValue(sanitized, maxLength);
    } catch (_) {
      return '[Un-stringifyable Object]';
    }
  }
}
