import '../../core/models/debug_state_diff_entry.dart';
import '../../core/models/debug_state_diff_type.dart';
import '../../core/models/debug_kit_sanitizer_config.dart';
import '../sanitizer/debug_log_sanitizer.dart';

/// Builds lightweight structured diffs for JSON-like state values.
///
/// The builder intentionally avoids reflection and only deeply compares
/// `Map` and `List` values. Arbitrary Dart objects fall back to a single
/// root-level change entry using their sanitized `toString()` output.
class DebugStateDiffBuilder {
  static DebugKitSanitizerConfig _activeSanitizerConfig =
      const DebugKitSanitizerConfig();

  /// Builds a bounded list of diff entries from [previousValue] to [nextValue].
  static List<DebugStateDiffEntry> build(
    dynamic previousValue,
    dynamic nextValue, {
    int maxDepth = 5,
    int maxEntries = 50,
    int maxValuePreviewLength = 500,
    DebugKitSanitizerConfig sanitizerConfig = const DebugKitSanitizerConfig(),
  }) {
    if (maxEntries <= 0) return const [];

    final entries = <DebugStateDiffEntry>[];
    final previousConfig = _activeSanitizerConfig;
    _activeSanitizerConfig = sanitizerConfig;
    try {
      _diff(
        previousValue,
        nextValue,
        path: r'$',
        depth: 0,
        maxDepth: maxDepth,
        maxEntries: maxEntries,
        maxValuePreviewLength: maxValuePreviewLength,
        sanitizerConfig: sanitizerConfig,
        entries: entries,
      );
      return entries;
    } finally {
      _activeSanitizerConfig = previousConfig;
    }
  }

  static void _diff(
    dynamic previousValue,
    dynamic nextValue, {
    required String path,
    required int depth,
    required int maxDepth,
    required int maxEntries,
    required int maxValuePreviewLength,
    required DebugKitSanitizerConfig sanitizerConfig,
    required List<DebugStateDiffEntry> entries,
  }) {
    if (entries.length >= maxEntries) return;
    if (identical(previousValue, nextValue) || previousValue == nextValue) {
      return;
    }

    if (previousValue == null || nextValue == null) {
      if (previousValue == null && nextValue is Map) {
        _expandAddedMap(
          nextValue,
          path: path,
          depth: depth,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
        return;
      }
      if (previousValue == null && nextValue is List) {
        _expandAddedList(
          nextValue,
          path: path,
          depth: depth,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
        return;
      }
      if (nextValue == null && previousValue is Map) {
        _expandRemovedMap(
          previousValue,
          path: path,
          depth: depth,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
        return;
      }
      if (nextValue == null && previousValue is List) {
        _expandRemovedList(
          previousValue,
          path: path,
          depth: depth,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
        return;
      }
      entries.add(
        DebugStateDiffEntry(
          path: path,
          type: previousValue == null
              ? DebugStateDiffType.added
              : DebugStateDiffType.removed,
          previousValuePreview: _preview(previousValue, maxValuePreviewLength),
          nextValuePreview: _preview(nextValue, maxValuePreviewLength),
        ),
      );
      return;
    }

    if (depth >= maxDepth) {
      _addFallback(
          entries, path, previousValue, nextValue, maxValuePreviewLength);
      return;
    }

    if (previousValue is Map && nextValue is Map) {
      _diffMaps(
        previousValue,
        nextValue,
        path: path,
        depth: depth,
        maxDepth: maxDepth,
        maxEntries: maxEntries,
        maxValuePreviewLength: maxValuePreviewLength,
        sanitizerConfig: sanitizerConfig,
        entries: entries,
      );
      return;
    }

    if (previousValue is List && nextValue is List) {
      _diffLists(
        previousValue,
        nextValue,
        path: path,
        depth: depth,
        maxDepth: maxDepth,
        maxEntries: maxEntries,
        maxValuePreviewLength: maxValuePreviewLength,
        sanitizerConfig: sanitizerConfig,
        entries: entries,
      );
      return;
    }

    _addFallback(
        entries, path, previousValue, nextValue, maxValuePreviewLength);
  }

  static void _diffMaps(
    Map<dynamic, dynamic> previousValue,
    Map<dynamic, dynamic> nextValue, {
    required String path,
    required int depth,
    required int maxDepth,
    required int maxEntries,
    required int maxValuePreviewLength,
    required DebugKitSanitizerConfig sanitizerConfig,
    required List<DebugStateDiffEntry> entries,
  }) {
    final previousKeys = previousValue.keys.toList(growable: false);
    final nextKeys = nextValue.keys.toList(growable: false);
    final seen = <Object?>{};

    for (final key in previousKeys) {
      if (entries.length >= maxEntries) return;
      seen.add(key);
      final nextHasKey = nextValue.containsKey(key);
      final currentPath = _joinPath(path, key);
      if (!nextHasKey) {
        entries.add(
          DebugStateDiffEntry(
            path: currentPath,
            type: DebugStateDiffType.removed,
            previousValuePreview:
                _preview(previousValue[key], maxValuePreviewLength),
          ),
        );
        continue;
      }
      _diff(
        previousValue[key],
        nextValue[key],
        path: currentPath,
        depth: depth + 1,
        maxDepth: maxDepth,
        maxEntries: maxEntries,
        maxValuePreviewLength: maxValuePreviewLength,
        sanitizerConfig: sanitizerConfig,
        entries: entries,
      );
    }

    for (final key in nextKeys) {
      if (entries.length >= maxEntries) return;
      if (seen.contains(key)) continue;
      final currentPath = _joinPath(path, key);
      entries.add(
        DebugStateDiffEntry(
          path: currentPath,
          type: DebugStateDiffType.added,
          nextValuePreview: _preview(nextValue[key], maxValuePreviewLength),
        ),
      );
    }
  }

  static void _diffLists(
    List<dynamic> previousValue,
    List<dynamic> nextValue, {
    required String path,
    required int depth,
    required int maxDepth,
    required int maxEntries,
    required int maxValuePreviewLength,
    required DebugKitSanitizerConfig sanitizerConfig,
    required List<DebugStateDiffEntry> entries,
  }) {
    final maxLength = previousValue.length > nextValue.length
        ? previousValue.length
        : nextValue.length;

    for (var index = 0; index < maxLength; index++) {
      if (entries.length >= maxEntries) return;
      final previousHasIndex = index < previousValue.length;
      final nextHasIndex = index < nextValue.length;
      final currentPath = _joinListPath(path, index);

      if (!previousHasIndex) {
        entries.add(
          DebugStateDiffEntry(
            path: currentPath,
            type: DebugStateDiffType.added,
            nextValuePreview: _preview(nextValue[index], maxValuePreviewLength),
          ),
        );
        continue;
      }

      if (!nextHasIndex) {
        entries.add(
          DebugStateDiffEntry(
            path: currentPath,
            type: DebugStateDiffType.removed,
            previousValuePreview:
                _preview(previousValue[index], maxValuePreviewLength),
          ),
        );
        continue;
      }

      _diff(
        previousValue[index],
        nextValue[index],
        path: currentPath,
        depth: depth + 1,
        maxDepth: maxDepth,
        maxEntries: maxEntries,
        maxValuePreviewLength: maxValuePreviewLength,
        sanitizerConfig: sanitizerConfig,
        entries: entries,
      );
    }
  }

  static void _expandAddedMap(
    Map<dynamic, dynamic> value, {
    required String path,
    required int depth,
    required int maxDepth,
    required int maxEntries,
    required int maxValuePreviewLength,
    required DebugKitSanitizerConfig sanitizerConfig,
    required List<DebugStateDiffEntry> entries,
  }) {
    if (depth >= maxDepth) {
      entries.add(
        DebugStateDiffEntry(
          path: path,
          type: DebugStateDiffType.added,
          nextValuePreview: _preview(value, maxValuePreviewLength),
        ),
      );
      return;
    }

    for (final entry in value.entries) {
      if (entries.length >= maxEntries) return;
      final currentPath = _joinPath(path, entry.key);
      final nestedValue = entry.value;
      if (nestedValue is Map) {
        _expandAddedMap(
          nestedValue,
          path: currentPath,
          depth: depth + 1,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
      } else if (nestedValue is List) {
        _expandAddedList(
          nestedValue,
          path: currentPath,
          depth: depth + 1,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
      } else {
        entries.add(
          DebugStateDiffEntry(
            path: currentPath,
            type: DebugStateDiffType.added,
            nextValuePreview: _preview(nestedValue, maxValuePreviewLength),
          ),
        );
      }
    }
  }

  static void _expandRemovedMap(
    Map<dynamic, dynamic> value, {
    required String path,
    required int depth,
    required int maxDepth,
    required int maxEntries,
    required int maxValuePreviewLength,
    required DebugKitSanitizerConfig sanitizerConfig,
    required List<DebugStateDiffEntry> entries,
  }) {
    if (depth >= maxDepth) {
      entries.add(
        DebugStateDiffEntry(
          path: path,
          type: DebugStateDiffType.removed,
          previousValuePreview: _preview(value, maxValuePreviewLength),
        ),
      );
      return;
    }

    for (final entry in value.entries) {
      if (entries.length >= maxEntries) return;
      final currentPath = _joinPath(path, entry.key);
      final nestedValue = entry.value;
      if (nestedValue is Map) {
        _expandRemovedMap(
          nestedValue,
          path: currentPath,
          depth: depth + 1,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
      } else if (nestedValue is List) {
        _expandRemovedList(
          nestedValue,
          path: currentPath,
          depth: depth + 1,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
      } else {
        entries.add(
          DebugStateDiffEntry(
            path: currentPath,
            type: DebugStateDiffType.removed,
            previousValuePreview: _preview(nestedValue, maxValuePreviewLength),
          ),
        );
      }
    }
  }

  static void _expandAddedList(
    List<dynamic> value, {
    required String path,
    required int depth,
    required int maxDepth,
    required int maxEntries,
    required int maxValuePreviewLength,
    required DebugKitSanitizerConfig sanitizerConfig,
    required List<DebugStateDiffEntry> entries,
  }) {
    if (depth >= maxDepth) {
      entries.add(
        DebugStateDiffEntry(
          path: path,
          type: DebugStateDiffType.added,
          nextValuePreview: _preview(value, maxValuePreviewLength),
        ),
      );
      return;
    }

    for (var index = 0; index < value.length; index++) {
      if (entries.length >= maxEntries) return;
      final currentPath = _joinListPath(path, index);
      final nestedValue = value[index];
      if (nestedValue is Map) {
        _expandAddedMap(
          nestedValue,
          path: currentPath,
          depth: depth + 1,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
      } else if (nestedValue is List) {
        _expandAddedList(
          nestedValue,
          path: currentPath,
          depth: depth + 1,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
      } else {
        entries.add(
          DebugStateDiffEntry(
            path: currentPath,
            type: DebugStateDiffType.added,
            nextValuePreview: _preview(nestedValue, maxValuePreviewLength),
          ),
        );
      }
    }
  }

  static void _expandRemovedList(
    List<dynamic> value, {
    required String path,
    required int depth,
    required int maxDepth,
    required int maxEntries,
    required int maxValuePreviewLength,
    required DebugKitSanitizerConfig sanitizerConfig,
    required List<DebugStateDiffEntry> entries,
  }) {
    if (depth >= maxDepth) {
      entries.add(
        DebugStateDiffEntry(
          path: path,
          type: DebugStateDiffType.removed,
          previousValuePreview: _preview(value, maxValuePreviewLength),
        ),
      );
      return;
    }

    for (var index = 0; index < value.length; index++) {
      if (entries.length >= maxEntries) return;
      final currentPath = _joinListPath(path, index);
      final nestedValue = value[index];
      if (nestedValue is Map) {
        _expandRemovedMap(
          nestedValue,
          path: currentPath,
          depth: depth + 1,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
      } else if (nestedValue is List) {
        _expandRemovedList(
          nestedValue,
          path: currentPath,
          depth: depth + 1,
          maxDepth: maxDepth,
          maxEntries: maxEntries,
          maxValuePreviewLength: maxValuePreviewLength,
          sanitizerConfig: sanitizerConfig,
          entries: entries,
        );
      } else {
        entries.add(
          DebugStateDiffEntry(
            path: currentPath,
            type: DebugStateDiffType.removed,
            previousValuePreview: _preview(nestedValue, maxValuePreviewLength),
          ),
        );
      }
    }
  }

  static void _addFallback(
    List<DebugStateDiffEntry> entries,
    String path,
    dynamic previousValue,
    dynamic nextValue,
    int maxValuePreviewLength,
  ) {
    entries.add(
      DebugStateDiffEntry(
        path: path,
        type: DebugStateDiffType.changed,
        previousValuePreview: _preview(previousValue, maxValuePreviewLength),
        nextValuePreview: _preview(nextValue, maxValuePreviewLength),
      ),
    );
  }

  static String _preview(dynamic value, int maxValuePreviewLength) {
    if (value == null) return 'null';
    try {
      if (_activeSanitizerConfig.dangerouslyDisableSanitizer) {
        return value.toString();
      }
      final sanitized = DebugLogSanitizer.sanitizeMessage(
        value.toString(),
        config: _activeSanitizerConfig,
      );
      if (sanitized.length <= maxValuePreviewLength) return sanitized;
      return '${sanitized.substring(0, maxValuePreviewLength)}...';
    } catch (_) {
      return '[Un-stringifyable Object]';
    }
  }

  static String _joinPath(String parent, Object? key) {
    final keyText = _sanitizePathSegment(key?.toString() ?? 'null');
    if (parent == r'$') return keyText;
    return '$parent.$keyText';
  }

  static String _joinListPath(String parent, int index) {
    if (parent == r'$') return '[$index]';
    return '$parent[$index]';
  }

  static String _sanitizePathSegment(String value) {
    if (_activeSanitizerConfig.dangerouslyDisableSanitizer) {
      return value;
    }
    final sanitized = DebugLogSanitizer.sanitizeMessage(
      value,
      config: _activeSanitizerConfig,
    ).trim();
    if (sanitized.isEmpty) return 'value';
    return sanitized.length > 64
        ? '${sanitized.substring(0, 64)}...'
        : sanitized;
  }
}
