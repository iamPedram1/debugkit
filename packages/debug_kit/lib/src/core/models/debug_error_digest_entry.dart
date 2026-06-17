import 'debug_error_digest_severity.dart';
import 'debug_log_source.dart';

/// A grouped, de-duplicated error record produced by [DebugErrorDigestBuilder].
///
/// Each entry represents one distinct class of error observed in the current
/// log/trace session. Multiple raw [DebugLogEntry] instances with the same
/// error fingerprint are collapsed into a single [DebugErrorDigestEntry] with
/// a [count] that reflects how many times the error occurred (including
/// [DebugLogEntry.repeatCount] contributions).
///
/// All string fields are already sanitized — this model never stores raw
/// secrets, tokens, request bodies, response bodies, route extras, or provider
/// state objects.
class DebugErrorDigestEntry {
  /// Stable grouping key computed by [DebugErrorFingerprintBuilder].
  ///
  /// Two errors with the same fingerprint are considered the same class of
  /// failure and are merged into a single entry.
  final String fingerprint;

  /// Short, human-readable summary line for the error list.
  ///
  /// Derived from the normalized error message. Examples:
  /// - `'SocketException: Connection failed for /feed'`
  /// - `'Riverpod provider failed: authProvider'`
  /// - `'GET /api/profile failed 401'`
  final String title;

  /// Full sanitized error message from the most recent occurrence.
  final String message;

  /// Normalized message with volatile values stripped (used for display
  /// when it differs meaningfully from [message]).
  final String normalizedMessage;

  /// Aggregated severity across all contributing entries.
  final DebugErrorDigestSeverity severity;

  /// The log source that produced most occurrences of this error.
  final DebugLogSource source;

  /// Total number of times this error occurred, including
  /// [DebugLogEntry.repeatCount] from grouped log entries.
  final int count;

  /// When this error was first observed in the current session.
  final DateTime firstSeenAt;

  /// When this error was most recently observed.
  final DateTime lastSeenAt;

  /// ID of the most recent contributing [DebugLogEntry], if available.
  final int? latestLogId;

  /// IDs of up to 5 representative contributing [DebugLogEntry] instances.
  final List<int> sampleLogIds;

  /// IDs of related [DebugTrace] instances (failed or containing error events).
  final List<String> relatedTraceIds;

  /// Human-readable names of related traces (mirrors [relatedTraceIds]).
  final List<String> relatedTraceNames;

  /// Request IDs (Dio `dio_N` format) of related failed network requests.
  final List<String> relatedRequestIds;

  /// Sanitized route paths observed near this error.
  final List<String> relatedRoutes;

  /// Riverpod provider names associated with this error.
  final List<String> relatedProviderNames;

  /// Sanitized error string from the most recent occurrence.
  final String? latestError;

  /// Sanitized stack trace string from the most recent occurrence.
  final String? latestStackTrace;

  /// First useful stack frame (e.g. `auth_repository.dart:42`), extracted
  /// from the most recent stack trace.
  final String? firstUsefulStackFrame;

  /// Sanitized key-value metadata from a representative occurrence.
  ///
  /// Sensitive keys are already masked. Does not include request/response
  /// bodies, route extras, or provider state values.
  final Map<String, String>? sampleMetadata;

  /// Human-readable hints about this error — e.g. `'Repeated 12 times'`,
  /// `'Related to failed trace login_flow'`, `'HTTP 401 — check auth token'`.
  final List<String> healthHints;

  /// Creates a [DebugErrorDigestEntry].
  ///
  /// All parameters are required. Use [DebugErrorDigestBuilder] to create
  /// instances from live log/trace data rather than constructing directly.
  const DebugErrorDigestEntry({
    required this.fingerprint,
    required this.title,
    required this.message,
    required this.normalizedMessage,
    required this.severity,
    required this.source,
    required this.count,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.latestLogId,
    this.sampleLogIds = const [],
    this.relatedTraceIds = const [],
    this.relatedTraceNames = const [],
    this.relatedRequestIds = const [],
    this.relatedRoutes = const [],
    this.relatedProviderNames = const [],
    this.latestError,
    this.latestStackTrace,
    this.firstUsefulStackFrame,
    this.sampleMetadata,
    this.healthHints = const [],
  });

  /// Whether this entry has related context beyond the message itself.
  bool get hasRelatedContext =>
      relatedTraceIds.isNotEmpty ||
      relatedRequestIds.isNotEmpty ||
      relatedRoutes.isNotEmpty ||
      relatedProviderNames.isNotEmpty;
}
