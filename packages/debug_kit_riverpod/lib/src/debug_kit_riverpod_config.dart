/// Immutable configuration for [DebugKitRiverpodObserver].
///
/// All fields have safe, low-verbosity defaults so the observer can be dropped
/// in without extra configuration and will only log provider failures.
///
/// ```dart
/// // Default: only log failures
/// DebugKitRiverpodObserver()
///
/// // Verbose: log updates for specific providers with state preview
/// DebugKitRiverpodObserver(
///   config: DebugKitRiverpodConfig(
///     logProviderUpdates: true,
///     watchedProviders: {'authProvider', 'cartProvider'},
///     includeValuePreview: true,
///     maxValuePreviewLength: 200,
///   ),
/// )
/// ```
class DebugKitRiverpodConfig {
  /// Creates a [DebugKitRiverpodConfig].
  const DebugKitRiverpodConfig({
    this.logProviderUpdates = false,
    this.logProviderFailures = true,
    this.watchedProviders = const {},
    this.includeValuePreview = false,
    this.maxValuePreviewLength = 300,
  });

  /// Whether to log a [DebugLogLevel.debug] entry each time any provider
  /// updates its state.
  ///
  /// Defaults to `false` to avoid flooding the console with high-frequency
  /// state changes. When enabled, consider using [watchedProviders] to limit
  /// which providers emit update logs.
  ///
  /// > **Warning:** enabling this in production builds may reveal state
  /// > transition patterns. Keep `false` unless needed for debugging.
  final bool logProviderUpdates;

  /// Whether to log a [DebugLogLevel.error] entry when a provider throws an
  /// unhandled exception.
  ///
  /// Defaults to `true`. This is the primary use-case for the observer —
  /// disable only if you handle all provider errors elsewhere.
  final bool logProviderFailures;

  /// When non-empty, update logs are emitted only for providers whose name is
  /// in this set.
  ///
  /// Provider names must match the `name` parameter passed to the Riverpod
  /// provider constructor:
  /// ```dart
  /// final authProvider = StateProvider<User?>((ref) => null, name: 'authProvider');
  /// ```
  ///
  /// **Failures are not affected** — [logProviderFailures] applies to all
  /// providers regardless of this set.
  ///
  /// Defaults to an empty set (log all providers when updates are enabled).
  final Set<String> watchedProviders;

  /// Whether to call `.toString()` on the new provider value and include a
  /// truncated preview in the log metadata under the `'value_preview'` key.
  ///
  /// Defaults to `false`. When `true`:
  /// - The string is passed through [DebugLogSanitizer.sanitizeMessage].
  /// - It is truncated to [maxValuePreviewLength] characters.
  /// - If `.toString()` throws, `'[Un-stringifyable Object]'` is used instead.
  ///
  /// > **Warning:** if a model's `toString()` returns raw PII that does not
  /// > contain obvious secret keywords, it may appear in the preview. Keep
  /// > `false` in production builds.
  final bool includeValuePreview;

  /// Maximum length (in characters) of the value preview string before it is
  /// truncated with `'...'`.
  ///
  /// Applies only when [includeValuePreview] is `true`.
  /// Defaults to `300`.
  final int maxValuePreviewLength;
}
