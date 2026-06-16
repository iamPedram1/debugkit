import 'package:intl/intl.dart';
import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_trace.dart';
import 'debug_trace_export_formatter.dart';

class DebugLogExportFormatter {
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

  static String formatEntry(DebugLogEntry entry) {
    final buffer = StringBuffer();
    final time = DateFormat('HH:mm:ss').format(entry.timestamp);

    buffer.write('[${entry.level.label}][${entry.source.label}] $time');
    if (entry.requestId != null) buffer.write('  ${entry.requestId}');
    if (entry.traceId != null) {
      buffer.write('  Trace: ${entry.traceName ?? entry.traceId}');
      if (entry.traceStep != null) buffer.write(' step=${entry.traceStep}');
    }
    buffer.writeln();

    buffer.writeln('Message: ${entry.message}');

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
