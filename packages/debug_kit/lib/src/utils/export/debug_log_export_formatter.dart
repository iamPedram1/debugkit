import 'package:intl/intl.dart';
import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_trace.dart';
import 'debug_trace_export_formatter.dart';

/// Pure, stateless formatter that converts log entries and traces to a
/// human-readable plain-text export string.
///
/// All inputs are expected to already be sanitized — this class never
/// re-sanitizes or inspects values for secrets. It trusts that the store
/// contains only safe data.
///
/// Used by [DebugLogFileExporter] to produce the exported `.txt` file content
/// and by the clipboard copy action in the console screen.
class DebugLogExportFormatter {
  /// Formats [logs] (and optionally [traces]) into a complete export string.
  ///
  /// Grouped entries (where [DebugLogEntry.repeatCount] > 1) are exported as
  /// a single block with repeat count, first-seen, and last-seen timestamps.
  /// They are **never** expanded into N duplicate lines.
  ///
  /// - [logs]: the list of [DebugLogEntry] instances to format.
  /// - [traces]: optional list of [DebugTrace] instances appended after logs.
  static String formatLogs(List<DebugLogEntry> logs,
      {List<DebugTrace>? traces}) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    buffer.writeln('DebugKit Logs');
    buffer.writeln('Exported: ${dateFormat.format(now)}');
    buffer.writeln('Total   : ${logs.length} entries');
    buffer.writeln(
        '============================================================');
    buffer.writeln();

    for (final entry in logs) {
      buffer.writeln(formatEntry(entry));
      buffer.writeln(
          '------------------------------------------------------------');
    }

    // Append traces section if provided
    if (traces != null && traces.isNotEmpty) {
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
