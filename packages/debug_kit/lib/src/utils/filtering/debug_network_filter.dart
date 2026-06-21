import '../../core/models/debug_network_filter_state.dart';
import '../../core/models/debug_network_sort_option.dart';
import '../../core/models/debug_network_status_family.dart';
import '../../core/models/debug_network_transaction.dart';
import '../../core/models/debug_network_transaction_phase.dart';

/// Applies [state] to [transactions] and returns a filtered, sorted snapshot.
List<DebugNetworkTransaction> applyNetworkFiltersAndSort(
  List<DebugNetworkTransaction> transactions,
  DebugNetworkFilterState state,
) {
  final filtered = transactions.where((transaction) {
    if (state.traceId != null && transaction.traceId != state.traceId) {
      return false;
    }

    if (state.methods.isNotEmpty &&
        !state.methods.contains(transaction.method)) {
      return false;
    }

    if (state.statuses.isNotEmpty &&
        !_matchesStatusFilters(transaction, state.statuses)) {
      return false;
    }

    if (state.slowOnly && !transaction.isSlow(state.slowThresholdMs)) {
      return false;
    }

    if (state.errorsOnly && !transaction.isFailed) {
      return false;
    }

    if (state.pendingOnly && !transaction.isPending) {
      return false;
    }

    if (state.searchQuery.trim().isNotEmpty &&
        !_matchesSearch(transaction, state.searchQuery)) {
      return false;
    }

    return true;
  }).toList();

  filtered.sort((a, b) => _compareTransactions(a, b, state.sortOption));
  return List.unmodifiable(filtered);
}

bool _matchesStatusFilters(
  DebugNetworkTransaction transaction,
  Set<DebugNetworkStatusFilter> filters,
) {
  if (filters.contains(DebugNetworkStatusFilter.all)) return true;

  for (final filter in filters) {
    switch (filter) {
      case DebugNetworkStatusFilter.all:
        return true;
      case DebugNetworkStatusFilter.pending:
        if (transaction.phase == DebugNetworkTransactionPhase.pending) {
          return true;
        }
        break;
      case DebugNetworkStatusFilter.completed:
        if (transaction.phase == DebugNetworkTransactionPhase.completed) {
          return true;
        }
        break;
      case DebugNetworkStatusFilter.failed:
        if (transaction.isFailed) return true;
        break;
      case DebugNetworkStatusFilter.twoXX:
        if (transaction.statusFamily == DebugNetworkStatusFamily.twoXX) {
          return true;
        }
        break;
      case DebugNetworkStatusFilter.threeXX:
        if (transaction.statusFamily == DebugNetworkStatusFamily.threeXX) {
          return true;
        }
        break;
      case DebugNetworkStatusFilter.fourXX:
        if (transaction.statusFamily == DebugNetworkStatusFamily.fourXX) {
          return true;
        }
        break;
      case DebugNetworkStatusFilter.fiveXX:
        if (transaction.statusFamily == DebugNetworkStatusFamily.fiveXX) {
          return true;
        }
        break;
      case DebugNetworkStatusFilter.unknown:
        if (transaction.statusFamily == DebugNetworkStatusFamily.unknown) {
          return true;
        }
        break;
    }
  }

  return false;
}

bool _matchesSearch(DebugNetworkTransaction transaction, String query) {
  final normalized = query.toLowerCase();
  final values = <String?>[
    transaction.method,
    transaction.path,
    transaction.displayPath,
    transaction.url,
    transaction.host,
    transaction.query,
    transaction.statusCode?.toString(),
    transaction.durationMs?.toString(),
    transaction.requestId,
    transaction.traceId,
    transaction.traceName,
    transaction.errorType,
    transaction.errorMessage,
    transaction.stackTrace,
    transaction.backendRequestId,
    transaction.backendCorrelationId,
    transaction.backendTraceId,
    transaction.startedAtLabel,
    transaction.completedAtLabel,
    transaction.statusFamily.label,
    transaction.phase.label,
    ...transaction.metadata.entries.map((e) => '${e.key}=${e.value}'),
  ];

  for (final value in values) {
    if (value != null && value.toLowerCase().contains(normalized)) {
      return true;
    }
  }

  return false;
}

int _compareTransactions(
  DebugNetworkTransaction a,
  DebugNetworkTransaction b,
  DebugNetworkSortOption sortOption,
) {
  return switch (sortOption) {
    DebugNetworkSortOption.newestFirst =>
      b.startedAt.compareTo(a.startedAt) != 0
          ? b.startedAt.compareTo(a.startedAt)
          : b.logEntryId.compareTo(a.logEntryId),
    DebugNetworkSortOption.oldestFirst =>
      a.startedAt.compareTo(b.startedAt) != 0
          ? a.startedAt.compareTo(b.startedAt)
          : a.logEntryId.compareTo(b.logEntryId),
    DebugNetworkSortOption.durationDescending =>
      _compareNullableIntDesc(a.durationMs, b.durationMs) ??
          b.startedAt.compareTo(a.startedAt),
    DebugNetworkSortOption.durationAscending =>
      _compareNullableIntAsc(a.durationMs, b.durationMs) ??
          a.startedAt.compareTo(b.startedAt),
    DebugNetworkSortOption.statusAscending =>
      _compareNullableIntAsc(a.statusCode, b.statusCode) ??
          b.startedAt.compareTo(a.startedAt),
    DebugNetworkSortOption.statusDescending =>
      _compareNullableIntDesc(a.statusCode, b.statusCode) ??
          b.startedAt.compareTo(a.startedAt),
    DebugNetworkSortOption.methodAscending => a.method.compareTo(b.method) != 0
        ? a.method.compareTo(b.method)
        : b.startedAt.compareTo(a.startedAt),
    DebugNetworkSortOption.pathAscending =>
      a.displayPath.compareTo(b.displayPath) != 0
          ? a.displayPath.compareTo(b.displayPath)
          : b.startedAt.compareTo(a.startedAt),
    DebugNetworkSortOption.phaseAscending =>
      a.phase.index.compareTo(b.phase.index) != 0
          ? a.phase.index.compareTo(b.phase.index)
          : b.startedAt.compareTo(a.startedAt),
  };
}

int? _compareNullableIntAsc(int? a, int? b) {
  if (a == null && b == null) return null;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

int? _compareNullableIntDesc(int? a, int? b) {
  if (a == null && b == null) return null;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
