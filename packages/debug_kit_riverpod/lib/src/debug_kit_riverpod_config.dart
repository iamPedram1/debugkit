/// Immutable configuration for [DebugKitRiverpodObserver].
///
/// The observer records generic state events into DebugKit's dedicated State
/// tab by default. Mirroring those changes into the Logs tab is opt-in so
/// Riverpod updates no longer flood the main console.
typedef DebugKitRiverpodValueSerializer = Object? Function(Object? value);

/// Controls which Riverpod provider events DebugKit records.
///
/// Defaults record provider lifecycle events into the State tab, mirror errors
/// to Logs, and avoid value previews unless explicitly enabled.
class DebugKitRiverpodConfig {
  /// Creates a [DebugKitRiverpodConfig].
  const DebugKitRiverpodConfig({
    @Deprecated('Use recordProviderUpdates instead.') bool? logProviderUpdates,
    @Deprecated('Use recordProviderErrors instead.') bool? logProviderFailures,
    this.recordProviderAdds = true,
    bool? recordProviderUpdates,
    this.recordProviderDisposals = true,
    bool? recordProviderErrors,
    this.mirrorStateChangesToLogs = false,
    this.mirrorErrorsToLogs = true,
    this.watchedProviders = const {},
    this.includeValuePreview = false,
    this.valueSerializer,
    this.maxSerializationDepth = 5,
    this.maxSerializedEntries = 100,
    this.maxValuePreviewLength = 500,
    this.maxDiffDepth = 5,
    this.maxDiffEntries = 50,
  })  : logProviderUpdates =
            logProviderUpdates ?? (recordProviderUpdates ?? true),
        logProviderFailures =
            logProviderFailures ?? (recordProviderErrors ?? true),
        recordProviderUpdates =
            recordProviderUpdates ?? logProviderUpdates ?? true,
        recordProviderErrors =
            recordProviderErrors ?? logProviderFailures ?? true;

  /// Backward-compatible alias for [recordProviderUpdates].
  ///
  /// This now controls State tab recording, not log mirroring.
  @Deprecated('Use recordProviderUpdates instead.')
  final bool logProviderUpdates;

  /// Backward-compatible alias for [recordProviderErrors].
  ///
  /// This now controls State tab recording, not log mirroring.
  @Deprecated('Use recordProviderErrors instead.')
  final bool logProviderFailures;

  /// Whether provider additions are recorded into the State tab.
  final bool recordProviderAdds;

  /// Whether provider updates are recorded into the State tab.
  final bool recordProviderUpdates;

  /// Whether provider disposals are recorded into the State tab.
  final bool recordProviderDisposals;

  /// Whether provider failures are recorded into the State tab.
  final bool recordProviderErrors;

  /// Whether state changes should also be mirrored to the Logs tab.
  ///
  /// Defaults to `false` so provider updates stay out of the main console.
  final bool mirrorStateChangesToLogs;

  /// Whether provider failures should also be mirrored to the Logs tab.
  ///
  /// Defaults to `true` so errors remain easy to notice.
  final bool mirrorErrorsToLogs;

  /// When non-empty, events are recorded only for providers whose name is in
  /// this set.
  final Set<String> watchedProviders;

  /// Whether to stringify provider values for previews.
  ///
  /// When `true`, previews are sanitized and truncated before storage.
  final bool includeValuePreview;

  /// Optional custom serializer used before DebugKit falls back to defaults.
  ///
  /// Return a JSON-like object such as a `Map`, `List`, primitive, or `null`.
  /// If the serializer throws, DebugKit silently falls back to the built-in
  /// serializer pipeline.
  final DebugKitRiverpodValueSerializer? valueSerializer;

  /// Maximum recursion depth when converting provider values to structured
  /// JSON-like data.
  final int maxSerializationDepth;

  /// Maximum number of entries to serialize from a single `Map` or `Iterable`.
  final int maxSerializedEntries;

  /// Maximum preview length in characters.
  final int maxValuePreviewLength;

  /// Maximum recursion depth for structured state diffs.
  final int maxDiffDepth;

  /// Maximum number of structured diff entries recorded per event.
  final int maxDiffEntries;
}
