import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_log_level.dart';
import '../../core/models/debug_log_source.dart';

class DebugLogFilterState {
  final Set<DebugLogLevel> levels;
  final Set<DebugLogSource> sources;
  final String searchQuery;

  const DebugLogFilterState({
    this.levels = const {},
    this.sources = const {},
    this.searchQuery = '',
  });

  bool get hasActiveFilters =>
      levels.isNotEmpty || sources.isNotEmpty || searchQuery.isNotEmpty;

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
