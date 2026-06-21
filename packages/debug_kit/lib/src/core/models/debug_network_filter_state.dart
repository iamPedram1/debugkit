import 'debug_network_sort_option.dart';

/// Status filter categories used by the network inspector.
enum DebugNetworkStatusFilter {
  all,
  pending,
  completed,
  failed,
  twoXX,
  threeXX,
  fourXX,
  fiveXX,
  unknown;

  /// Human-readable label shown in chips and menus.
  String get label {
    return switch (this) {
      DebugNetworkStatusFilter.all => 'All',
      DebugNetworkStatusFilter.pending => 'Pending',
      DebugNetworkStatusFilter.completed => 'Completed',
      DebugNetworkStatusFilter.failed => 'Failed',
      DebugNetworkStatusFilter.twoXX => '2xx',
      DebugNetworkStatusFilter.threeXX => '3xx',
      DebugNetworkStatusFilter.fourXX => '4xx',
      DebugNetworkStatusFilter.fiveXX => '5xx',
      DebugNetworkStatusFilter.unknown => 'Unknown',
    };
  }
}

/// Immutable filtering/sorting state for the network inspector UI.
class DebugNetworkFilterState {
  /// Free-text query matched against method, path, URL, status, IDs, errors,
  /// trace names, and sanitized metadata values.
  final String searchQuery;

  /// Explicit HTTP method filters. Empty means all methods.
  final Set<String> methods;

  /// Status-family filters. Empty means all statuses.
  final Set<DebugNetworkStatusFilter> statuses;

  /// Shows only requests above the configured slow threshold when `true`.
  final bool slowOnly;

  /// Shows only requests that ended in a failure state when `true`.
  final bool errorsOnly;

  /// Shows only requests that are still pending when `true`.
  final bool pendingOnly;

  /// Restricts results to a specific trace ID when provided.
  final String? traceId;

  /// Sort order for the network list.
  final DebugNetworkSortOption sortOption;

  /// Slow-request threshold used by the "Slow" toggle.
  final int slowThresholdMs;

  const DebugNetworkFilterState({
    this.searchQuery = '',
    this.methods = const {},
    this.statuses = const {},
    this.slowOnly = false,
    this.errorsOnly = false,
    this.pendingOnly = false,
    this.traceId,
    this.sortOption = DebugNetworkSortOption.newestFirst,
    this.slowThresholdMs = 500,
  });

  /// Returns `true` when any filter differs from the default state.
  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      methods.isNotEmpty ||
      statuses.isNotEmpty ||
      slowOnly ||
      errorsOnly ||
      pendingOnly ||
      traceId != null;

  DebugNetworkFilterState copyWith({
    String? searchQuery,
    Set<String>? methods,
    Set<DebugNetworkStatusFilter>? statuses,
    bool? slowOnly,
    bool? errorsOnly,
    bool? pendingOnly,
    String? traceId,
    DebugNetworkSortOption? sortOption,
    int? slowThresholdMs,
  }) {
    return DebugNetworkFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      methods: methods ?? this.methods,
      statuses: statuses ?? this.statuses,
      slowOnly: slowOnly ?? this.slowOnly,
      errorsOnly: errorsOnly ?? this.errorsOnly,
      pendingOnly: pendingOnly ?? this.pendingOnly,
      traceId: traceId ?? this.traceId,
      sortOption: sortOption ?? this.sortOption,
      slowThresholdMs: slowThresholdMs ?? this.slowThresholdMs,
    );
  }
}
