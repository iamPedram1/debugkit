import 'debug_log_level.dart';
import 'debug_log_source.dart';

/// An immutable record of a single log event stored in [DebugLogStore].
///
/// All string fields are already sanitized before a [DebugLogEntry] is created
/// by [DebugKitController] — raw secrets, tokens, and private keys are never
/// stored. Use [copyWith] to produce updated versions of a live entry (e.g.
/// when the Dio adapter finalises a pending request with a status code).
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

  /// When the entry was recorded (UTC).
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
  });

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
    );
  }
}
