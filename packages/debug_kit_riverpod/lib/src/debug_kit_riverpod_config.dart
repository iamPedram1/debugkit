/// Configuration for the DebugKit Riverpod observer.
class DebugKitRiverpodConfig {
  const DebugKitRiverpodConfig({
    this.logProviderUpdates = false,
    this.logProviderFailures = true,
    this.watchedProviders = const {},
    this.includeValuePreview = false,
    this.maxValuePreviewLength = 300,
  });

  /// Whether to log when providers update their state.
  /// Defaults to false to avoid extreme log spam.
  final bool logProviderUpdates;

  /// Whether to log when providers encounter an error/exception.
  /// Defaults to true.
  final bool logProviderFailures;

  /// If non-empty, only provider updates for the specified provider names
  /// will be logged.
  /// Provider failures are not affected by this filter.
  final Set<String> watchedProviders;

  /// Whether to attempt a safe `toString()` on the provider value for the log metadata.
  /// Defaults to false.
  final bool includeValuePreview;

  /// The maximum string length of the value preview before it gets truncated.
  /// Defaults to 300 characters.
  final int maxValuePreviewLength;
}
