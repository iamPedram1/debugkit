import 'package:intl/intl.dart';
import '../../core/models/debug_error_digest.dart';
import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_network_endpoint_stats.dart';
import '../../core/models/debug_network_transaction.dart';
import '../../core/models/debug_state_event.dart';
import '../../core/models/debug_trace.dart';
import '../../core/models/debug_network_summary.dart';
import '../../utils/network/debug_network_transaction_builder.dart';
import 'debug_trace_export_formatter.dart';

/// Pure, stateless formatter that converts log entries, traces, and optional
/// diagnostic summaries to a human-readable plain-text export string.
///
/// All inputs are expected to already be sanitized — this class never
/// re-sanitizes or inspects values for secrets. It trusts that the store
/// contains only safe data.
///
/// Used by [DebugLogFileExporter] to produce the exported `.txt` file content
/// and by the clipboard copy action in the console screen.
class DebugLogExportFormatter {
  /// Formats [logs] (and optionally [traces] and [digest]) into a complete export string.
  ///
  /// Grouped entries (where [DebugLogEntry.repeatCount] > 1) are exported as
  /// a single block with repeat count, first-seen, and last-seen timestamps.
  /// They are **never** expanded into N duplicate lines.
  ///
  /// - [logs]: the list of [DebugLogEntry] instances to format.
  /// - [traces]: optional list of [DebugTrace] instances appended after logs.
  /// - [digest]: optional [DebugErrorDigest] appended as a final section.
  static String formatLogs(
    List<DebugLogEntry> logs, {
    List<DebugStateEvent>? stateEvents,
    List<DebugTrace>? traces,
    DebugErrorDigest? digest,
    DebugNetworkSummary? networkSummary,
    bool includeLogs = true,
    bool includeStateEvents = true,
    bool includeTraces = true,
    bool includeNetworkSummary = true,
    bool includeNetworkTransactions = true,
    bool includeDigest = true,
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    buffer.writeln('DebugKit Logs');
    buffer.writeln('Exported: ${dateFormat.format(now)}');
    buffer.writeln('Total   : ${includeLogs ? logs.length : 0} entries');
    buffer.writeln(
        '============================================================');
    buffer.writeln();

    if (includeLogs) {
      for (final entry in logs) {
        buffer.writeln(formatEntry(entry));
        buffer.writeln(
            '------------------------------------------------------------');
      }
    }

    if (includeStateEvents && stateEvents != null && stateEvents.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
          '============================================================');
      buffer.writeln();
      buffer.write(_StateExportFormatter.formatStateEvents(stateEvents));
    }

    // Append traces section if provided
    if (includeTraces && traces != null && traces.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
          '============================================================');
      buffer.writeln();
      buffer.write(DebugTraceExportFormatter.formatTraces(traces));

      final failedSummary =
          DebugTraceExportFormatter.formatFailedSummary(traces);
      if (failedSummary.isNotEmpty) {
        buffer.writeln();
        buffer.write(failedSummary);
      }
    }

    if (includeNetworkSummary &&
        networkSummary != null &&
        !networkSummary.isEmpty) {
      buffer.writeln();
      buffer.writeln(
          '============================================================');
      buffer.writeln();
      buffer.write(DebugNetworkSummaryExportFormatter.formatSummary(
        networkSummary,
      ));
    }

    final networkTransactions = includeNetworkTransactions
        ? DebugNetworkTransactionBuilder.build(logs)
        : const <DebugNetworkTransaction>[];
    if (networkTransactions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
          '============================================================');
      buffer.writeln();
      buffer.write(
        DebugNetworkTransactionExportFormatter.formatTransactions(
          networkTransactions,
        ),
      );
    }

    // Append error digest section if provided
    if (includeDigest && digest != null && !digest.isEmpty) {
      buffer.writeln();
      buffer.writeln(
          '============================================================');
      buffer.writeln();
      buffer.write(DebugErrorDigestExportFormatter.formatDigest(digest));
    }

    return buffer.toString();
  }

  /// Formats a single [DebugLogEntry] as a multi-line block.
  ///
  /// When [DebugLogEntry.repeatCount] > 1 the header line includes `×N` and
  /// the block gains `First seen` / `Last seen` lines. The entry is always
  /// emitted as **one block** regardless of how many times it was repeated.
  ///
  /// Header line: `[LEVEL][SOURCE] HH:mm:ss ×N  requestId  Trace: name step=N`
  static String formatEntry(DebugLogEntry entry) {
    final buffer = StringBuffer();
    final timeFormat = DateFormat('HH:mm:ss');
    final fullFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
    final time = timeFormat.format(entry.timestamp);
    final isRepeated = entry.repeatCount > 1;

    // Header line
    buffer.write('[${entry.level.label}][${entry.source.label}] $time');
    if (isRepeated) buffer.write(' ×${entry.repeatCount}');
    if (entry.requestId != null) buffer.write('  ${entry.requestId}');
    if (entry.traceId != null) {
      buffer.write('  Trace: ${entry.traceName ?? entry.traceId}');
      if (entry.traceStep != null) buffer.write(' step=${entry.traceStep}');
    }
    buffer.writeln();

    buffer.writeln('Message: ${entry.message}');

    // Repeat timing lines
    if (isRepeated) {
      buffer.writeln('First seen: ${fullFormat.format(entry.timestamp)}');
      if (entry.lastSeenAt != null) {
        buffer.writeln('Last seen : ${fullFormat.format(entry.lastSeenAt!)}');
      }
    }

    if (entry.location != null) {
      buffer.writeln('Location: ${entry.location}');
    }

    if (entry.error != null) {
      buffer.writeln('Error: ${entry.error}');
    }

    if (entry.metadata != null && entry.metadata!.isNotEmpty) {
      buffer.write('Meta: ');
      buffer.writeln(
          entry.metadata!.entries.map((e) => '${e.key}=${e.value}').join(' '));
    }

    if (entry.details != null) {
      buffer.writeln('Details:');
      buffer.writeln(entry.details);
    }

    if (entry.payloadPreview != null) {
      buffer.writeln('Payload:');
      buffer.writeln(entry.payloadPreview);
    }

    if (entry.responsePreview != null) {
      buffer.writeln('Response:');
      buffer.writeln(entry.responsePreview);
    }

    if (entry.stackTrace != null) {
      buffer.writeln('Stack:');
      buffer.writeln(entry.stackTrace);
    }

    return buffer.toString();
  }
}

class _StateExportFormatter {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  static String formatStateEvents(List<DebugStateEvent> events) {
    final buffer = StringBuffer();
    buffer.writeln('State Events');
    buffer.writeln('Total     : ${events.length}');
    buffer.writeln(
        '============================================================');
    buffer.writeln();

    for (final event in events) {
      buffer.writeln(formatStateEvent(event));
      buffer.writeln(
          '------------------------------------------------------------');
    }

    return buffer.toString();
  }

  static String formatStateEvent(DebugStateEvent event) {
    final buffer = StringBuffer();
    buffer.write('[${event.eventType.label.toUpperCase()}][STATE] ');
    buffer.write(event.name);
    if (event.type != null && event.type!.trim().isNotEmpty) {
      buffer.write('  (${event.type})');
    }
    buffer.writeln();
    buffer.writeln('  Source    : ${event.source}');
    buffer.writeln('  Timestamp : ${_dateFormat.format(event.timestamp)}');
    if (event.previousValuePreview != null) {
      buffer.writeln('  Previous  : ${event.previousValuePreview}');
    }
    if (event.nextValuePreview != null) {
      buffer.writeln('  Next      : ${event.nextValuePreview}');
    }
    if (event.diffPreview != null) {
      buffer.writeln('  Diff      : ${event.diffPreview}');
    }
    if (event.changes.isNotEmpty) {
      buffer.writeln('  Changes   :');
      for (final change in event.changes) {
        buffer.writeln('    - ${change.path} (${change.type.label})');
        if (change.previousValuePreview != null) {
          buffer.writeln('      Previous: ${change.previousValuePreview}');
        }
        if (change.nextValuePreview != null) {
          buffer.writeln('      Next    : ${change.nextValuePreview}');
        }
      }
    }
    if (event.metadata != null && event.metadata!.isNotEmpty) {
      buffer.writeln('  Metadata  :');
      final keys = event.metadata!.keys.toList()..sort();
      for (final key in keys) {
        buffer.writeln('    $key=${event.metadata![key]}');
      }
    }
    if (event.error != null) {
      buffer.writeln('  Error     : ${event.error}');
    }
    if (event.stackTrace != null) {
      buffer.writeln('  Stack     :');
      for (final line in event.stackTrace!.split('\n').take(10)) {
        buffer.writeln('    $line');
      }
    }
    return buffer.toString();
  }
}

/// Pure formatter for exporting transaction rows and transaction details.
class DebugNetworkTransactionExportFormatter {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  static String formatTransactions(List<DebugNetworkTransaction> transactions) {
    final buffer = StringBuffer();

    buffer.writeln('Network Requests');
    buffer.writeln('Total     : ${transactions.length}');
    buffer.writeln(
        '============================================================');
    buffer.writeln();

    for (final transaction in transactions) {
      buffer.writeln(formatTransaction(transaction));
      buffer.writeln(
          '------------------------------------------------------------');
    }

    return buffer.toString();
  }

  static String formatTransaction(DebugNetworkTransaction transaction) {
    final buffer = StringBuffer();
    buffer.write(
      '[${transaction.method}] ${transaction.displayPath} · ${transaction.statusLabel} · ${transaction.phase.label}',
    );
    buffer.writeln();
    buffer
        .writeln('  Started   : ${_dateFormat.format(transaction.startedAt)}');
    if (transaction.completedAt != null) {
      buffer.writeln(
        '  Completed : ${_dateFormat.format(transaction.completedAt!)}',
      );
    }
    buffer.writeln('  Duration  : ${transaction.durationLabel}');
    if (transaction.requestId != null) {
      buffer.writeln('  RequestId : ${transaction.requestId}');
    }
    if (transaction.traceId != null) {
      buffer.write(
          '  Trace     : ${transaction.traceName ?? transaction.traceId}');
      if (transaction.traceStep != null) {
        buffer.write(' step=${transaction.traceStep}');
      }
      buffer.writeln();
    }
    if (transaction.backendRequestId != null) {
      buffer.writeln('  Backend   : request=${transaction.backendRequestId}');
    }
    if (transaction.backendCorrelationId != null) {
      buffer.writeln(
        '             correlation=${transaction.backendCorrelationId}',
      );
    }
    if (transaction.backendTraceId != null) {
      buffer.writeln('             trace=${transaction.backendTraceId}');
    }
    if (transaction.errorType != null || transaction.errorMessage != null) {
      buffer.writeln(
        '  Error     : ${transaction.errorType ?? ''}${transaction.errorType != null && transaction.errorMessage != null ? ' — ' : ''}${transaction.errorMessage ?? ''}',
      );
    }
    if (transaction.stackTrace != null) {
      buffer.writeln('  Stack     :');
      for (final line in transaction.stackTrace!.split('\n').take(10)) {
        buffer.writeln('    $line');
      }
    }
    if (transaction.requestHeadersPreview != null) {
      buffer.writeln('  Request headers:');
      buffer.writeln(_indent(transaction.requestHeadersPreview!));
    }
    if (transaction.responseHeadersPreview != null) {
      buffer.writeln('  Response headers:');
      buffer.writeln(_indent(transaction.responseHeadersPreview!));
    }
    if (transaction.requestBodyPreview != null) {
      buffer.writeln('  Request body:');
      buffer.writeln(_indent(transaction.requestBodyPreview!));
    }
    if (transaction.responseBodyPreview != null) {
      buffer.writeln('  Response body:');
      buffer.writeln(_indent(transaction.responseBodyPreview!));
    }
    if (transaction.metadata.isNotEmpty) {
      final entries = transaction.metadata.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      buffer.writeln('  Meta      :');
      for (final entry in entries) {
        buffer.writeln('    ${entry.key}=${entry.value}');
      }
    }
    return buffer.toString();
  }

  static String formatTransactionDetail(DebugNetworkTransaction transaction) {
    return formatTransaction(transaction);
  }

  static String _indent(String text) {
    return text.split('\n').map((line) => '    $line').join('\n');
  }
}

/// Pure formatter for exporting [DebugNetworkSummary] data as plain text.
class DebugNetworkSummaryExportFormatter {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  static String formatSummary(DebugNetworkSummary summary) {
    final buffer = StringBuffer();
    final maxDuration =
        summary.maxDurationMs != null ? '${summary.maxDurationMs}ms' : 'n/a';
    final minDuration =
        summary.minDurationMs != null ? '${summary.minDurationMs}ms' : 'n/a';

    buffer.writeln('Network Summary');
    buffer.writeln('Generated : ${_dateFormat.format(summary.generatedAt)}');
    buffer.writeln('Total     : ${summary.totalRequests}');
    buffer.writeln('Completed : ${summary.completedRequests}');
    buffer.writeln('Failed    : ${summary.failedRequests}');
    buffer.writeln('Pending   : ${summary.pendingRequests}');
    buffer.writeln('Slow      : ${summary.slowRequests}');
    buffer.writeln(
        'Status    : 2xx=${summary.statusBreakdown.status2xx}, 3xx=${summary.statusBreakdown.status3xx}, 4xx=${summary.statusBreakdown.status4xx}, 5xx=${summary.statusBreakdown.status5xx}, unknown=${summary.statusBreakdown.statusUnknown}');
    buffer.writeln(
        'Timing    : avg=${summary.averageDurationMs}ms max=$maxDuration min=$minDuration slow>=${summary.slowRequestThresholdMs}ms');

    if (summary.topFailingEndpoints.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Top failing endpoints:');
      for (final endpoint in summary.topFailingEndpoints) {
        final lastStatus = endpoint.lastStatusCode != null
            ? '${endpoint.lastStatusCode}'
            : 'unknown';
        buffer.writeln(
          '  - ${endpoint.method} ${endpoint.path} — failed=${endpoint.failedCount}/${endpoint.totalCount}, lastStatus=$lastStatus',
        );
        _writeEndpointContext(buffer, endpoint);
      }
    }

    if (summary.slowestEndpoints.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Slowest endpoints:');
      for (final endpoint in summary.slowestEndpoints) {
        buffer.writeln(
          '  - ${endpoint.method} ${endpoint.path} — max=${endpoint.maxDurationMs ?? 'n/a'}ms, avg=${endpoint.averageDurationMs ?? 'n/a'}ms, slow=${endpoint.slowCount}/${endpoint.totalCount}',
        );
        _writeEndpointContext(buffer, endpoint);
      }
    }

    if (summary.mostCalledEndpoints.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Most called endpoints:');
      for (final endpoint in summary.mostCalledEndpoints) {
        buffer.writeln(
          '  - ${endpoint.method} ${endpoint.path} — total=${endpoint.totalCount}, lastSeen=${endpoint.lastSeenAt != null ? _dateFormat.format(endpoint.lastSeenAt!) : 'n/a'}',
        );
      }
    }

    return buffer.toString();
  }

  static void _writeEndpointContext(
    StringBuffer buffer,
    DebugNetworkEndpointStats endpoint,
  ) {
    if (endpoint.relatedTraceIds.isNotEmpty) {
      buffer.writeln('    traces=${endpoint.relatedTraceIds.join(', ')}');
    }
    if (endpoint.relatedRequestIds.isNotEmpty) {
      buffer.writeln('    requests=${endpoint.relatedRequestIds.join(', ')}');
    }
    if (endpoint.backendRequestIds.isNotEmpty) {
      buffer.writeln(
          '    backendRequestIds=${endpoint.backendRequestIds.join(', ')}');
    }
    if (endpoint.backendCorrelationIds.isNotEmpty) {
      buffer.writeln(
          '    backendCorrelationIds=${endpoint.backendCorrelationIds.join(', ')}');
    }
    if (endpoint.backendTraceIds.isNotEmpty) {
      buffer.writeln(
          '    backendTraceIds=${endpoint.backendTraceIds.join(', ')}');
    }
  }
}

/// Pure, stateless formatter for exporting [DebugErrorDigest] data as
/// human-readable plain text.
///
/// Only sanitized values are formatted — this class never re-sanitizes or
/// inspects raw data. It trusts that the digest was built from already-safe
/// store contents.
class DebugErrorDigestExportFormatter {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Formats [digest] as a complete "DebugKit Error Digest" section.
  static String formatDigest(DebugErrorDigest digest) {
    final buffer = StringBuffer();

    buffer.writeln('DebugKit Error Digest');
    buffer.writeln('Generated : ${_dateFormat.format(digest.generatedAt)}');
    buffer.writeln('Total     : ${digest.totalErrors} occurrences');
    buffer.writeln('Unique    : ${digest.uniqueErrors} error classes');
    if (digest.failedNetworkCount > 0) {
      buffer.writeln(
          'Network   : ${digest.failedNetworkCount} failed request(s)');
    }
    if (digest.failedTraceCount > 0) {
      buffer.writeln('Traces    : ${digest.failedTraceCount} failed trace(s)');
    }
    buffer.writeln(
        '============================================================');
    buffer.writeln();

    for (final entry in digest.entries) {
      buffer.writeln(formatDigestEntry(entry));
      buffer.writeln(
          '------------------------------------------------------------');
    }

    return buffer.toString();
  }

  /// Formats a single [DebugErrorDigestEntry] as a multi-line block.
  ///
  /// Example output:
  /// ```
  /// [ERROR][DIO] GET /api/profile · 401 ×12
  ///   Severity   : ERROR
  ///   Source     : DIO
  ///   Count      : ×12
  ///   First seen : 2026-06-17 10:00:00
  ///   Last seen  : 2026-06-17 10:05:00
  ///   Error      : DioException [bad response]: ...
  ///   Frame      : auth_repository.dart:42
  ///   Traces     : login_flow, refresh_profile
  ///   Requests   : dio_1, dio_8
  ///   Hints      : HTTP 401 — check authentication/authorization
  /// ```
  static String formatDigestEntry(entry) {
    // entry is DebugErrorDigestEntry (imported via DebugErrorDigest)
    final buffer = StringBuffer();

    buffer.write('[${entry.severity.label}][${entry.source.label}] ');
    buffer.write(entry.title);
    if (entry.count > 1) buffer.write(' ×${entry.count}');
    buffer.writeln();

    buffer.writeln('  Severity   : ${entry.severity.label}');
    buffer.writeln('  Source     : ${entry.source.label}');
    buffer.writeln('  Count      : ×${entry.count}');
    buffer.writeln('  First seen : ${_dateFormat.format(entry.firstSeenAt)}');
    buffer.writeln('  Last seen  : ${_dateFormat.format(entry.lastSeenAt)}');

    if (entry.latestError != null) {
      buffer.writeln('  Error      : ${entry.latestError}');
    }

    if (entry.firstUsefulStackFrame != null) {
      buffer.writeln('  Frame      : ${entry.firstUsefulStackFrame}');
    }

    if (entry.relatedTraceNames.isNotEmpty) {
      buffer.writeln('  Traces     : ${entry.relatedTraceNames.join(', ')}');
    }

    if (entry.relatedRequestIds.isNotEmpty) {
      buffer.writeln('  Requests   : ${entry.relatedRequestIds.join(', ')}');
    }

    if (entry.relatedRoutes.isNotEmpty) {
      buffer.writeln('  Routes     : ${entry.relatedRoutes.join(', ')}');
    }

    if (entry.relatedProviderNames.isNotEmpty) {
      buffer.writeln('  Providers  : ${entry.relatedProviderNames.join(', ')}');
    }

    if (entry.healthHints.isNotEmpty) {
      for (final hint in entry.healthHints) {
        buffer.writeln('  Hint       : $hint');
      }
    }

    if (entry.latestStackTrace != null) {
      buffer.writeln('  Stack:');
      // Indent each stack line for readability
      for (final line in entry.latestStackTrace!.split('\n').take(10)) {
        buffer.writeln('    $line');
      }
    }

    return buffer.toString();
  }
}
