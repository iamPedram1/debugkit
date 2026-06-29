import 'debug_log_level.dart';
import 'debug_log_source.dart';

/// An immutable record of a single log event stored in [DebugLogStore].
///
/// All string fields are already sanitized before a [DebugLogEntry] is created
/// by [DebugKitController] — raw secrets, tokens, and private keys are never
/// stored. Use [copyWith] to produce updated versions of a live entry (e.g.
/// when the Dio adapter finalises a pending request with a status code).
///
/// When [DebugKitConfig.groupRepeatedLogs] is `true`, consecutive identical
/// logs are collapsed into a single entry. [repeatCount] tracks how many times
/// the log was emitted, [timestamp] remains the first occurrence, and
/// [lastSeenAt] records the most recent emission time.
class DebugLogEntry {
  /// Auto-incrementing integer assigned by [DebugLogStore.getNextId].
  ///
  /// Stable within a session; resets when DebugKit is re-initialized.
  final int id;

  /// Severity of the log event.
  final DebugLogLevel level;

  /// Subsystem that produced the log.
  final DebugLogSource source;

  /// The sanitized human-readable message.
  final String message;

  /// When the entry was first recorded (UTC).
  ///
  /// Always the timestamp of the *first* occurrence, even when the entry has
  /// been repeated and [repeatCount] is greater than 1.
  final DateTime timestamp;

  /// Optional sanitized error string (e.g. `exception.toString()`).
  final String? error;

  /// Optional trimmed and sanitized stack trace string.
  ///
  /// Trimmed to a maximum of 25 lines by [DebugLogSanitizer.trimStackTrace].
  final String? stackTrace;

  /// Optional source file and line parsed from the call-site stack trace.
  ///
  /// Populated only when [DebugKitConfig.captureAppCallLocation] is `true`
  /// and [source] is [DebugLogSource.app].
  /// Format: `filename.dart:line:col`
  final String? location;

  /// Optional free-form detail string.
  ///
  /// Not used by the core logging path — available for adapter-specific
  /// extended information.
  final String? details;

  /// Optional key-value metadata map. Keys and values are plain strings.
  ///
  /// All keys are sanitized before storage. Keys that match known sensitive
  /// patterns (e.g. `api_key`, `token`) have their values masked.
  final Map<String, String>? metadata;

  /// Optional sanitized preview of a request payload.
  ///
  /// Not populated by default. Adapters may set this field only when the user
  /// has explicitly opted in to payload capture.
  final String? payloadPreview;

  /// Optional sanitized preview of a response body.
  ///
  /// Not populated by default. Adapters may set this field only when the user
  /// has explicitly opted in to response capture.
  final String? responsePreview;

  /// Optional request identifier used to correlate a pending Dio log entry
  /// with its subsequent response or error update.
  ///
  /// Format: `'dio_<n>'` where `n` is a per-interceptor counter.
  final String? requestId;

  /// Optional trace ID linking this log entry to a [DebugTrace].
  ///
  /// Automatically populated when the log is emitted inside an active
  /// [DebugKit.trace.run] zone.
  final String? traceId;

  /// Optional human-readable name of the associated trace.
  ///
  /// Mirrors [DebugTrace.name] for convenient display without looking up
  /// the trace object.
  final String? traceName;

  /// Optional step counter within the associated trace.
  ///
  /// Can be used by callers who want to record an explicit step index on a
  /// log entry; not set automatically by the core.
  final int? traceStep;

  // ---------------------------------------------------------------------------
  // Repeat grouping fields
  // ---------------------------------------------------------------------------

  /// How many times this log has been emitted consecutively.
  ///
  /// Defaults to `1` for all new entries. Incremented by [DebugLogStore] when
  /// [DebugKitConfig.groupRepeatedLogs] is `true` and the incoming entry has
  /// the same [fingerprint] as the current tail entry.
  ///
  /// Always ≥ 1.
  final int repeatCount;

  /// When the most recent repeat was recorded.
  ///
  /// `null` when [repeatCount] is `1`. Set to [DateTime.now()] whenever the
  /// store increments [repeatCount]. The [timestamp] field always reflects the
  /// *first* occurrence.
  final DateTime? lastSeenAt;

  /// Creates a [DebugLogEntry]. All required fields must be provided.
  ///
  /// In practice entries are created only by [DebugKitController.log] after
  /// sanitization — direct construction is for tests and adapter packages.
  DebugLogEntry({
    required this.id,
    required this.level,
    required this.source,
    required this.message,
    required this.timestamp,
    this.error,
    this.stackTrace,
    this.location,
    this.details,
    this.metadata,
    this.payloadPreview,
    this.responsePreview,
    this.requestId,
    this.traceId,
    this.traceName,
    this.traceStep,
    this.repeatCount = 1,
    this.lastSeenAt,
  }) : assert(repeatCount >= 1, 'repeatCount must be at least 1');

  /// Whether this entry was created by app/user code rather than an adapter.
  bool get isUserLog =>
      source == DebugLogSource.app || source == DebugLogSource.userAction;

  /// Whether this entry was produced by an optional adapter package.
  bool get isAdapterLog =>
      source == DebugLogSource.dio ||
      source == DebugLogSource.riverpod ||
      source == DebugLogSource.router;

  // ---------------------------------------------------------------------------
  // Fingerprint
  // ---------------------------------------------------------------------------

  /// A stable string that identifies the "kind" of this log for grouping.
  ///
  /// Two entries with the same fingerprint are considered equivalent and may
  /// be collapsed into a single grouped entry when consecutive.
  ///
  /// **Important:** the [DebugLogStore] never groups entries that carry a
  /// [requestId], regardless of fingerprint equality. This protects network
  /// log entries from being merged — each one must remain individually
  /// addressable for [DebugKitController.updateLogByRequestId] to work.
  ///
  /// **Included in the fingerprint:**
  /// - [level] — different severities are never merged.
  /// - [source] — app vs DIO vs router logs are never merged.
  /// - [message] — the primary log text.
  /// - [error] — two entries with different errors are distinct.
  /// - First line of [stackTrace] — enough to distinguish call sites without
  ///   over-specificity.
  /// - [traceId] — logs from different traces are never merged.
  /// - Stable metadata keys: all metadata *except* the volatile keys
  ///   `duration_ms`, `request_id`, and `response_headers` which change on
  ///   every network call even when the logical event is the same.
  ///
  /// **Excluded from the fingerprint:**
  /// - [timestamp] / [lastSeenAt] — timing is irrelevant for grouping.
  /// - [id] — internal identity, not semantic content.
  /// - [repeatCount] / [lastSeenAt] — grouping state, not content.
  /// - [location] — call-site varies across build flavors; excluding it avoids
  ///   false negatives in release vs profile vs debug builds.
  /// - `duration_ms`, `response_headers` metadata — volatile per call.
  String get fingerprint {
    final metaPart = _stableMetadata();
    final stackFirst = _firstStackLine();
    return '${level.index}|${source.index}|$message|${error ?? ''}|${stackFirst ?? ''}|${traceId ?? ''}|$metaPart';
  }

  /// Returns metadata sorted by key with volatile keys excluded.
  String _stableMetadata() {
    if (metadata == null || metadata!.isEmpty) return '';
    const volatileKeys = {'duration_ms', 'request_id', 'response_headers'};
    final stable = metadata!.entries
        .where((e) => !volatileKeys.contains(e.key))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return stable.map((e) => '${e.key}=${e.value}').join(',');
  }

  /// Returns only the first line of [stackTrace], or `null`.
  String? _firstStackLine() {
    if (stackTrace == null) return null;
    return stackTrace!.split('\n').first.trim();
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  /// Returns a copy of this entry with the specified fields replaced.
  ///
  /// [id], [source], [timestamp], and [location] are always preserved from
  /// the original because they represent identity and origin, not mutable
  /// state. This is used by [DebugKitController.updateLogByRequestId] to
  /// finalize Dio log entries.
  DebugLogEntry copyWith({
    String? message,
    DebugLogLevel? level,
    String? error,
    String? stackTrace,
    String? details,
    Map<String, String>? metadata,
    String? payloadPreview,
    String? responsePreview,
    String? requestId,
    String? traceId,
    String? traceName,
    int? traceStep,
    int? repeatCount,
    DateTime? lastSeenAt,
  }) {
    return DebugLogEntry(
      id: id,
      level: level ?? this.level,
      source: source,
      message: message ?? this.message,
      timestamp: timestamp,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      location: location,
      details: details ?? this.details,
      metadata: metadata ?? this.metadata,
      payloadPreview: payloadPreview ?? this.payloadPreview,
      responsePreview: responsePreview ?? this.responsePreview,
      requestId: requestId ?? this.requestId,
      traceId: traceId ?? this.traceId,
      traceName: traceName ?? this.traceName,
      traceStep: traceStep ?? this.traceStep,
      repeatCount: repeatCount ?? this.repeatCount,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  /// Returns a copy with [repeatCount] incremented by 1 and [lastSeenAt] set
  /// to [now].
  ///
  /// Used by [DebugLogStore] when a consecutive duplicate is detected.
  DebugLogEntry copyWithRepeatIncrement(DateTime now) {
    return copyWith(
      repeatCount: repeatCount + 1,
      lastSeenAt: now,
    );
  }
}
