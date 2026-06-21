/// Lifecycle phase for a network transaction.
enum DebugNetworkTransactionPhase {
  pending,
  completed,
  failed,
  cancelled,
  unknown;

  /// Human-readable label for UI and export sections.
  String get label {
    return switch (this) {
      DebugNetworkTransactionPhase.pending => 'Pending',
      DebugNetworkTransactionPhase.completed => 'Completed',
      DebugNetworkTransactionPhase.failed => 'Failed',
      DebugNetworkTransactionPhase.cancelled => 'Cancelled',
      DebugNetworkTransactionPhase.unknown => 'Unknown',
    };
  }
}
