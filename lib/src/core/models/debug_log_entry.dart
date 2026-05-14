import 'debug_log_level.dart';
import 'debug_log_source.dart';

class DebugLogEntry {
  final int id;
  final DebugLogLevel level;
  final DebugLogSource source;
  final String message;
  final DateTime timestamp;

  final String? error;
  final String? stackTrace;
  final String? location;
  final String? details;
  final Map<String, String>? metadata;
  final String? payloadPreview;
  final String? responsePreview;
  final String? requestId;
  final String? traceId;
  final String? traceName;
  final int? traceStep;

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
