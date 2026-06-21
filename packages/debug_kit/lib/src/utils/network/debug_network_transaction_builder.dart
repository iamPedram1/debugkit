import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_log_source.dart';
import '../../core/models/debug_network_status_family.dart';
import '../../core/models/debug_network_transaction.dart';
import '../../core/models/debug_network_transaction_phase.dart';

/// Pure builder that converts sanitized log entries into network transactions.
class DebugNetworkTransactionBuilder {
  DebugNetworkTransactionBuilder._();

  static List<DebugNetworkTransaction> build(List<DebugLogEntry> logs) {
    final transactions = <DebugNetworkTransaction>[];

    for (final entry in logs) {
      final transaction = _tryBuild(entry);
      if (transaction != null) {
        transactions.add(transaction);
      }
    }

    transactions.sort((a, b) {
      final byStartedAt = b.startedAt.compareTo(a.startedAt);
      if (byStartedAt != 0) return byStartedAt;
      return b.logEntryId.compareTo(a.logEntryId);
    });

    return List.unmodifiable(transactions);
  }

  static DebugNetworkTransaction? _tryBuild(DebugLogEntry entry) {
    if (!_isNetworkTransaction(entry)) return null;

    final metadata = entry.metadata ?? const <String, String>{};
    final method = _readMethod(entry);
    final rawPath = _readPath(entry);
    final phase = _readPhase(entry);

    if (method == null || rawPath == null || phase == null) return null;

    final normalized = _normalizePathAndQuery(
      path: rawPath,
      url: _readUrl(entry),
      query: _readMetadataValue(entry, const ['query']),
    );

    final statusCode = _readStatusCode(entry);
    final durationMs = _readDurationMs(entry);
    final errorType = _readMetadataValue(
      entry,
      const ['errorType', 'error_type'],
    );
    final errorMessage = _readMetadataValue(
          entry,
          const ['errorMessage', 'error_message'],
        ) ??
        entry.error;

    return DebugNetworkTransaction(
      logEntryId: entry.id,
      requestId: entry.requestId ??
          _readMetadataValue(
            entry,
            const ['requestId', 'request_id'],
          ),
      traceId: entry.traceId ??
          _readMetadataValue(entry, const ['traceId', 'trace_id']),
      traceName: entry.traceName ??
          _readMetadataValue(entry, const ['traceName', 'trace_name']),
      traceStep: entry.traceStep ?? _readTraceStep(entry),
      method: method,
      url: normalized.url ?? _readUrl(entry),
      host: normalized.host,
      path: normalized.path,
      query: normalized.query,
      startedAt: entry.lastSeenAt ?? entry.timestamp,
      statusCode: statusCode,
      statusFamily: _statusFamily(statusCode),
      durationMs: durationMs,
      phase: phase,
      errorType: errorType,
      errorMessage: errorMessage,
      stackTrace: entry.stackTrace,
      backendRequestId: _readMetadataValue(
        entry,
        const ['backendRequestId', 'backend_request_id'],
      ),
      backendCorrelationId: _readMetadataValue(
        entry,
        const ['backendCorrelationId', 'backend_correlation_id'],
      ),
      backendTraceId: _readMetadataValue(
        entry,
        const ['backendTraceId', 'backend_trace_id'],
      ),
      metadata: Map.unmodifiable(metadata),
      requestHeadersPreview: _readMetadataValue(
        entry,
        const ['requestHeadersPreview', 'request_headers_preview'],
      ),
      responseHeadersPreview: _readMetadataValue(
        entry,
        const ['responseHeadersPreview', 'response_headers_preview'],
      ),
      requestBodyPreview: entry.payloadPreview ??
          _readMetadataValue(entry, const [
            'requestBodyPreview',
            'request_body_preview',
          ]),
      responseBodyPreview: entry.responsePreview ??
          _readMetadataValue(entry, const [
            'responseBodyPreview',
            'response_body_preview',
          ]),
    );
  }

  static bool _isNetworkTransaction(DebugLogEntry entry) {
    final kind = _readMetadataValue(entry, const ['kind']);
    if (kind?.toLowerCase() == 'networktransaction') return true;
    if (entry.source == DebugLogSource.dio) return true;
    return false;
  }

  static String? _readMethod(DebugLogEntry entry) {
    final raw = _readMetadataValue(entry, const ['method']);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim().toUpperCase();
  }

  static String? _readPath(DebugLogEntry entry) {
    return _readMetadataValue(entry, const ['path']);
  }

  static String? _readUrl(DebugLogEntry entry) {
    return _readMetadataValue(
      entry,
      const ['sanitizedUrl', 'url', 'sanitized_url'],
    );
  }

  static DebugNetworkTransactionPhase? _readPhase(DebugLogEntry entry) {
    final raw = _readMetadataValue(entry, const ['phase']);
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'pending' => DebugNetworkTransactionPhase.pending,
      'completed' => DebugNetworkTransactionPhase.completed,
      'failed' => DebugNetworkTransactionPhase.failed,
      'cancelled' || 'canceled' => DebugNetworkTransactionPhase.cancelled,
      _ => DebugNetworkTransactionPhase.unknown,
    };
  }

  static int? _readStatusCode(DebugLogEntry entry) {
    final raw = _readMetadataValue(
      entry,
      const ['status', 'status_code', 'statusCode'],
    );
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  static int? _readDurationMs(DebugLogEntry entry) {
    final raw = _readMetadataValue(
      entry,
      const ['durationMs', 'duration_ms', 'duration'],
    );
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  static int? _readTraceStep(DebugLogEntry entry) {
    final raw = _readMetadataValue(entry, const ['traceStep', 'trace_step']);
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  static String? _readMetadataValue(DebugLogEntry entry, List<String> keys) {
    final metadata = entry.metadata;
    if (metadata == null || metadata.isEmpty) return null;
    for (final key in keys) {
      final value = metadata[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static ({String path, String? query, String? host, String? url})
      _normalizePathAndQuery({
    required String path,
    String? query,
    String? url,
  }) {
    var normalizedPath = path.trim();
    String? normalizedQuery = query?.trim();
    String? normalizedHost;
    String? normalizedUrl = url?.trim();

    Uri? parsedUri;
    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      parsedUri = Uri.tryParse(normalizedUrl);
    }

    parsedUri ??= Uri.tryParse(normalizedPath);

    if (parsedUri != null) {
      if (parsedUri.hasScheme && parsedUri.host.isNotEmpty) {
        normalizedHost = parsedUri.host;
        normalizedUrl ??= parsedUri.toString();
      }

      if (normalizedPath.isEmpty ||
          normalizedPath.contains('://') ||
          normalizedPath.startsWith(parsedUri.path)) {
        normalizedPath = parsedUri.path.isEmpty ? '/' : parsedUri.path;
      }

      if (normalizedQuery == null || normalizedQuery.isEmpty) {
        normalizedQuery = parsedUri.query.isEmpty ? null : parsedUri.query;
      }
    }

    if (normalizedPath.isEmpty) {
      normalizedPath = '/';
    }
    if (!normalizedPath.startsWith('/')) {
      normalizedPath = '/$normalizedPath';
    }

    return (
      path: normalizedPath,
      query: normalizedQuery,
      host: normalizedHost,
      url: normalizedUrl,
    );
  }

  static DebugNetworkStatusFamily _statusFamily(int? statusCode) {
    if (statusCode == null) return DebugNetworkStatusFamily.unknown;
    if (statusCode >= 200 && statusCode <= 299) {
      return DebugNetworkStatusFamily.twoXX;
    }
    if (statusCode >= 300 && statusCode <= 399) {
      return DebugNetworkStatusFamily.threeXX;
    }
    if (statusCode >= 400 && statusCode <= 499) {
      return DebugNetworkStatusFamily.fourXX;
    }
    if (statusCode >= 500 && statusCode <= 599) {
      return DebugNetworkStatusFamily.fiveXX;
    }
    return DebugNetworkStatusFamily.unknown;
  }
}
