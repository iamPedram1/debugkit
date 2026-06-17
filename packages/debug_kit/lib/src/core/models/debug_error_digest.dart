import 'debug_error_digest_entry.dart';

/// The complete error digest produced by [DebugErrorDigestBuilder].
///
/// Aggregates all distinct error classes observed in the current DebugKit
/// session. Built on demand from the current [DebugLogStore] and
/// [DebugTraceStore] contents via [DebugKitController.buildErrorDigest].
///
/// Immutable snapshot — a new [DebugErrorDigest] is produced each time the
/// digest is (re)computed.
class DebugErrorDigest {
  /// When this digest was generated.
  final DateTime generatedAt;

  /// Total number of individual error occurrences across all entries
  /// (sum of [DebugErrorDigestEntry.count] for all entries).
  final int totalErrors;

  /// Number of distinct error classes (i.e. [entries.length]).
  final int uniqueErrors;

  /// All distinct error entries, sorted by usefulness:
  /// 1. Severity (fatal → error → warning).
  /// 2. Count descending (most frequent first).
  /// 3. Most recently seen first (as tiebreaker).
  final List<DebugErrorDigestEntry> entries;

  /// Up to 5 entries with the highest [DebugErrorDigestEntry.count].
  final List<DebugErrorDigestEntry> topRepeatedErrors;

  /// Up to 5 entries with the most recent [DebugErrorDigestEntry.lastSeenAt].
  final List<DebugErrorDigestEntry> latestErrors;

  /// Number of failed [DebugTrace] instances included in this digest.
  final int failedTraceCount;

  /// Number of failed Dio network request log entries.
  final int failedNetworkCount;

  /// Creates a [DebugErrorDigest].
  const DebugErrorDigest({
    required this.generatedAt,
    required this.totalErrors,
    required this.uniqueErrors,
    required this.entries,
    required this.topRepeatedErrors,
    required this.latestErrors,
    required this.failedTraceCount,
    required this.failedNetworkCount,
  });

  /// Returns `true` when no errors were detected in the current session.
  bool get isEmpty => entries.isEmpty;
}
