/// Sort order options for the network inspector.
enum DebugNetworkSortOption {
  newestFirst,
  oldestFirst,
  durationDescending,
  durationAscending,
  statusAscending,
  statusDescending,
  methodAscending,
  pathAscending,
  phaseAscending;

  /// Short label for UI selection chips or menu items.
  String get label {
    return switch (this) {
      DebugNetworkSortOption.newestFirst => 'Newest first',
      DebugNetworkSortOption.oldestFirst => 'Oldest first',
      DebugNetworkSortOption.durationDescending => 'Longest first',
      DebugNetworkSortOption.durationAscending => 'Shortest first',
      DebugNetworkSortOption.statusAscending => 'Status ↑',
      DebugNetworkSortOption.statusDescending => 'Status ↓',
      DebugNetworkSortOption.methodAscending => 'Method',
      DebugNetworkSortOption.pathAscending => 'Path',
      DebugNetworkSortOption.phaseAscending => 'Phase',
    };
  }
}
