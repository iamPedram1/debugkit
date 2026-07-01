import 'dart:collection';
import 'dart:convert';

import 'package:debug_kit/debug_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'debug_kit_riverpod_config.dart';

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
    required DebugKitRiverpodValueSerializer? valueSerializer,
    required int maxSerializationDepth,
    required int maxSerializedEntries,
    required DebugKitSanitizerConfig sanitizerConfig,
  }) {
    try {
      final serializedPrevious = serializeValue(
        previousValue,
        valueSerializer: valueSerializer,
        maxSerializationDepth: maxSerializationDepth,
        maxSerializedEntries: maxSerializedEntries,
        maxValuePreviewLength: maxValuePreviewLength,
        sanitizerConfig: sanitizerConfig,
      );
      final serializedNext = serializeValue(
        nextValue,
        valueSerializer: valueSerializer,
        maxSerializationDepth: maxSerializationDepth,
        maxSerializedEntries: maxSerializedEntries,
        maxValuePreviewLength: maxValuePreviewLength,
        sanitizerConfig: sanitizerConfig,
      );

      return DebugStateDiffBuilder.build(
        serializedPrevious,
        serializedNext,
        maxDepth: maxDepth,
        maxEntries: maxEntries,
        maxValuePreviewLength: maxValuePreviewLength,
        sanitizerConfig: sanitizerConfig,
      );
    } catch (_) {
      return const [];
    }
  }

  /// Turns a provider value into a JSON-like structure when possible.
  ///
  /// The result is safe to diff, preview, and export. On failure it falls back
  /// to a bounded preview map rather than throwing.
  static Object? serializeValue(
    Object? value, {
    required DebugKitRiverpodValueSerializer? valueSerializer,
    required int maxSerializationDepth,
    required int maxSerializedEntries,
    required int maxValuePreviewLength,
    required DebugKitSanitizerConfig sanitizerConfig,
  }) {
    final state = _RiverpodValueSerializationState(
      valueSerializer: valueSerializer,
      maxSerializationDepth: maxSerializationDepth,
      maxSerializedEntries: maxSerializedEntries,
      maxValuePreviewLength: maxValuePreviewLength,
      sanitizerConfig: sanitizerConfig,
    );
    return state.serialize(value, depth: 0);
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
  /// Used to produce state value previews and metadata previews.
  static String safeValuePreview(
    dynamic value,
    int maxLength, {
    DebugKitSanitizerConfig sanitizerConfig = const DebugKitSanitizerConfig(),
  }) {
    try {
      final serialized = serializeValue(
        value,
        valueSerializer: null,
        maxSerializationDepth: 5,
        maxSerializedEntries: 100,
        maxValuePreviewLength: maxLength,
        sanitizerConfig: sanitizerConfig,
      );

      final preview =
          _renderPreview(serialized, sanitizerConfig: sanitizerConfig);
      if (sanitizerConfig.dangerouslyDisableSanitizer) {
        return truncateValue(preview, maxLength);
      }

      final sanitized = DebugLogSanitizer.sanitizeMessage(
        preview,
        config: sanitizerConfig,
      );
      return truncateValue(sanitized, maxLength);
    } catch (_) {
      return '[Un-stringifyable Object]';
    }
  }

  static String _renderPreview(
    Object? value, {
    required DebugKitSanitizerConfig sanitizerConfig,
  }) {
    if (value == null) return 'null';
    if (value is String || value is num || value is bool) {
      return value.toString();
    }
    if (value is Map || value is List) {
      try {
        return jsonEncode(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }
}

class _RiverpodValueSerializationState {
  _RiverpodValueSerializationState({
    required this.valueSerializer,
    required this.maxSerializationDepth,
    required this.maxSerializedEntries,
    required this.maxValuePreviewLength,
    required this.sanitizerConfig,
  });

  final DebugKitRiverpodValueSerializer? valueSerializer;
  final int maxSerializationDepth;
  final int maxSerializedEntries;
  final int maxValuePreviewLength;
  final DebugKitSanitizerConfig sanitizerConfig;
  final Set<Object> _seen = HashSet<Object>.identity();

  Object? serialize(Object? value, {required int depth}) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    if (valueSerializer != null) {
      try {
        final custom = valueSerializer!(value);
        return _serializeCandidate(custom, depth: depth);
      } catch (_) {
        // Fall through to the built-in pipeline.
      }
    }

    return _serializeCandidate(value, depth: depth);
  }

  Object? _serializeCandidate(
    Object? value, {
    required int depth,
  }) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    if (value is AsyncValue) {
      return _serializeAsyncValue(value, depth: depth);
    }

    if (depth >= maxSerializationDepth) {
      return _fallbackPreview(value);
    }

    if (value is Map) {
      if (_markSeen(value)) {
        return _fallbackPreview(value, circular: true);
      }
      final result = <Object?, Object?>{};
      var count = 0;
      for (final entry in value.entries) {
        if (count >= maxSerializedEntries) break;
        result[entry.key] = serialize(entry.value, depth: depth + 1);
        count++;
      }
      return result;
    }

    if (value is Iterable) {
      if (_markSeen(value)) {
        return _fallbackPreview(value, circular: true);
      }
      final result = <Object?>[];
      var count = 0;
      for (final item in value) {
        if (count >= maxSerializedEntries) break;
        result.add(serialize(item, depth: depth + 1));
        count++;
      }
      return result;
    }

    final toJsonValue = _tryInvoke(value, 'toJson');
    if (toJsonValue != _NoValue.instance) {
      return serialize(toJsonValue, depth: depth + 1);
    }

    final toMapValue = _tryInvoke(value, 'toMap');
    if (toMapValue != _NoValue.instance) {
      return serialize(toMapValue, depth: depth + 1);
    }

    return _fallbackPreview(value);
  }

  Object? _serializeAsyncValue(AsyncValue<dynamic> value,
      {required int depth}) {
    if (value.isLoading) {
      return const {'asyncState': 'loading'};
    }

    if (value.hasError) {
      return {
        'asyncState': 'error',
        'error': _preview(value.error),
        'stackTrace': _preview(value.stackTrace),
      };
    }

    final asyncData = value.value;
    return {
      'asyncState': 'data',
      'value': serialize(asyncData, depth: depth + 1),
    };
  }

  Object? _fallbackPreview(
    Object? value, {
    bool circular = false,
  }) {
    final runtimeType = value?.runtimeType.toString() ?? 'null';
    return <String, String>{
      'runtimeType': _sanitize(runtimeType),
      'preview': circular ? '[Circular reference]' : _preview(value),
    };
  }

  String _preview(Object? value) {
    if (value == null) return 'null';
    try {
      final preview = value.toString();
      if (sanitizerConfig.dangerouslyDisableSanitizer) {
        return RiverpodLogHelpers.truncateValue(
          preview,
          maxValuePreviewLength,
        );
      }

      final sanitized = DebugLogSanitizer.sanitizeMessage(
        preview,
        config: sanitizerConfig,
      );
      return RiverpodLogHelpers.truncateValue(
        sanitized,
        maxValuePreviewLength,
      );
    } catch (_) {
      return '[Un-stringifyable Object]';
    }
  }

  String _sanitize(String value) {
    if (sanitizerConfig.dangerouslyDisableSanitizer) return value;
    return DebugLogSanitizer.sanitizeMessage(
      value,
      config: sanitizerConfig,
    );
  }

  bool _markSeen(Object value) {
    if (_seen.contains(value)) return true;
    _seen.add(value);
    return false;
  }

  static const _NoValue _noValue = _NoValue.instance;

  Object? _tryInvoke(Object value, String methodName) {
    try {
      final dynamic dynamicValue = value;
      final result =
          methodName == 'toJson' ? dynamicValue.toJson() : dynamicValue.toMap();
      return result;
    } catch (_) {
      return _noValue;
    }
  }
}

enum _NoValue {
  instance;
}
