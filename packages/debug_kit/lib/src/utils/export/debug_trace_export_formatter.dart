import 'package:intl/intl.dart';
import '../../core/models/debug_trace.dart';
import '../../core/models/debug_trace_status.dart';
import '../trace/debug_trace_analyzer.dart';

/// Pure formatter for exporting [DebugTrace] data as human-readable text.
///
/// Only sanitized values are formatted — this class never re-sanitizes or
/// inspects raw data. It trusts that the store already holds clean values.
class DebugTraceExportFormatter {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _timeFormat = DateFormat('HH:mm:ss.SSS');

  /// Formats a list of traces into a complete section for inclusion in an
  /// export file.
  static String formatTraces(
    List<DebugTrace> traces, {
    Duration slowThreshold = DebugTraceAnalyzer.defaultSlowThreshold,
  }) {
    if (traces.isEmpty) {
      return 'DebugKit Traces\nTotal: 0\n';
    }

    final buffer = StringBuffer();
    buffer.writeln('DebugKit Traces');
    buffer.writeln('Total: ${traces.length}');
    buffer.writeln(
        '============================================================');
    buffer.writeln();

    for (final trace in traces) {
      buffer.writeln(formatTrace(trace, slowThreshold: slowThreshold));
      buffer.writeln(
          '------------------------------------------------------------');
    }

    return buffer.toString();
  }

  /// Formats a single [DebugTrace] with its timeline and health warnings.
  static String formatTrace(
    DebugTrace trace, {
    Duration slowThreshold = DebugTraceAnalyzer.defaultSlowThreshold,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('Trace: ${trace.name}');
    buffer.writeln('  ID     : ${trace.id}');
    buffer.writeln('  Status : ${trace.status.label}');
    buffer.writeln('  Started: ${_dateFormat.format(trace.startedAt)}');

    if (trace.endedAt != null) {
      buffer.writeln('  Ended  : ${_dateFormat.format(trace.endedAt!)}');
    }

    if (trace.durationMs != null) {
      buffer.writeln('  Duration: ${trace.durationMs}ms');
    }

    if (trace.parentTraceId != null) {
      buffer.writeln('  Parent : ${trace.parentTraceId}');
    }

    if (trace.metadata != null && trace.metadata!.isNotEmpty) {
      buffer.write('  Meta   : ');
      buffer.writeln(
          trace.metadata!.entries.map((e) => '${e.key}=${e.value}').join(' '));
    }

    if (trace.errorSummary != null) {
      buffer.writeln('  Error  : ${trace.errorSummary}');
    }

    // Timeline
    if (trace.events.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('  Timeline (${trace.events.length} events):');
      for (final event in trace.events) {
        final elapsed = event.elapsedMs(trace.startedAt);
        final elapsedStr = '+${elapsed}ms'.padRight(10);
        final typeLabel = '[${event.type.label}]'.padRight(8);
        buffer.write('    $elapsedStr $typeLabel ${event.message}');

        if (event.requestId != null) {
          buffer.write('  req=${event.requestId}');
        }
        if (event.durationMs != null) {
          buffer.write('  ${event.durationMs}ms');
        }
        if (event.error != null) {
          buffer.write('  error=${event.error}');
        }
        buffer.writeln();

        if (event.metadata != null && event.metadata!.isNotEmpty) {
          final meta = event.metadata!.entries
              .map((e) => '${e.key}=${e.value}')
              .join(' ');
          buffer.writeln('              meta: $meta');
        }
      }
    }

    // Health warnings
    final warnings =
        DebugTraceAnalyzer.analyze(trace, slowThreshold: slowThreshold);
    if (warnings.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('  Health Warnings:');
      for (final w in warnings) {
        buffer.writeln('    - $w');
      }
    }

    return buffer.toString();
  }

  /// Formats a summary section of failed traces only.
  static String formatFailedSummary(List<DebugTrace> traces) {
    final failed =
        traces.where((t) => t.status == DebugTraceStatus.failed).toList();

    if (failed.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('Failed Traces (${failed.length}):');
    for (final trace in failed) {
      final durationStr =
          trace.durationMs != null ? '${trace.durationMs}ms' : 'n/a';
      buffer.writeln(
          '  - ${trace.name} [${trace.id}] duration=$durationStr error=${trace.errorSummary ?? 'unknown'}');
    }
    return buffer.toString();
  }

  /// Returns the timestamp of the export for use in file headers.
  static String exportHeader(DateTime now) {
    return 'Exported: ${_timeFormat.format(now)}';
  }
}
