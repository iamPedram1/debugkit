import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_log_level.dart';
import '../../core/models/debug_log_source.dart';

/// Immutable filter state used by the log console UI.
///
/// Holds the active level chips, source chips, and search query. Call [apply]
/// to produce a filtered subset of a log list. Use [copyWith] to derive an
/// updated state when the user changes a filter.
///
/// The console screen holds a single [DebugLogFilterState] in its `State` and
/// rebuilds whenever the user interacts with the filter bar.
class DebugLogFilterState {
  /// Set of [DebugLogLevel] values to include.
  ///
  /// Empty means "all levels" (no level filter is active).
  final Set<DebugLogLevel> levels;

  /// Set of [DebugLogSource] values to include.
  ///
  /// Empty means "all sources" (no source filter is active).
  final Set<DebugLogSource> sources;

  /// Free-text search query.
  ///
  /// Empty string means "no text filter". Matching is case-insensitive and
  /// covers [DebugLogEntry.message], [DebugLogEntry.error],
  /// [DebugLogEntry.stackTrace], [DebugLogEntry.location],
  /// [DebugLogEntry.requestId], and [DebugLogEntry.metadata] values.
  final String searchQuery;

  /// Creates a [DebugLogFilterState].
  ///
  /// All filters default to "inactive" (empty sets and empty string).
  const DebugLogFilterState({
    this.levels = const {},
    this.sources = const {},
    this.searchQuery = '',
  });

  /// Returns `true` when any filter is active.
  ///
  /// Used by the console screen to show/hide the filter banner and to switch
  /// the export action label from "Export logs" to "Export filtered logs".
  bool get hasActiveFilters =>
      levels.isNotEmpty || sources.isNotEmpty || searchQuery.isNotEmpty;

  /// Returns a new [DebugLogFilterState] with the specified fields replaced.
  DebugLogFilterState copyWith({
    Set<DebugLogLevel>? levels,
    Set<DebugLogSource>? sources,
    String? searchQuery,
  }) {
    return DebugLogFilterState(
      levels: levels ?? this.levels,
      sources: sources ?? this.sources,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Applies all active filters to [logs] and returns the matching subset.
  ///
  /// Returns [logs] unchanged when [hasActiveFilters] is `false`.
  ///
  /// Filter rules (all must pass for an entry to be included):
  /// 1. **Level filter**: entry's level must be in [levels] (if non-empty).
  /// 2. **Source filter**: entry's source must be in [sources] (if non-empty).
  /// 3. **Text filter**: [searchQuery] must match at least one of
  ///    message, error, stackTrace, location, requestId, or any metadata value
  ///    (case-insensitive).
  List<DebugLogEntry> apply(List<DebugLogEntry> logs) {
    if (!hasActiveFilters) return logs;

    return logs.where((entry) {
      if (levels.isNotEmpty && !levels.contains(entry.level)) return false;
      if (sources.isNotEmpty && !sources.contains(entry.source)) return false;
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matches = entry.message.toLowerCase().contains(query) ||
            (entry.error?.toLowerCase().contains(query) ?? false) ||
            (entry.stackTrace?.toLowerCase().contains(query) ?? false) ||
            (entry.location?.toLowerCase().contains(query) ?? false) ||
            (entry.requestId?.toLowerCase().contains(query) ?? false) ||
            (entry.metadata?.values
                    .any((v) => v.toLowerCase().contains(query)) ??
                false);
        if (!matches) return false;
      }
      return true;
    }).toList();
  }
}
