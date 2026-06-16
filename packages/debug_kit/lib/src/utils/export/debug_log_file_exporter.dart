import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_trace.dart';
import 'debug_log_export_formatter.dart';

/// Platform-level export helper that writes log (and trace) data to a
/// temporary file and opens the system share sheet, or copies to the
/// clipboard as a fallback.
///
/// All content is produced by [DebugLogExportFormatter], which only uses
/// already-sanitized values from the in-memory store.
class DebugLogFileExporter {
  /// Returns the export filename for a given [timestamp].
  ///
  /// Format: `debugkit-logs-YYYYMMDD-HHmmss.txt`
  ///
  /// The filename contains only lowercase alphanumeric characters, hyphens,
  /// and a dot, making it safe for all major filesystems.
  ///
  /// Example: `debugkit-logs-20260616-143022.txt`
  static String buildFileName(DateTime timestamp) {
    final formatted = DateFormat('yyyyMMdd-HHmmss').format(timestamp);
    return 'debugkit-logs-$formatted.txt';
  }

  /// Formats [logs] (and optional [traces]) and copies the result to the
  /// system clipboard.
  ///
  /// - [logs]: log entries to include.
  /// - [traces]: optional trace entries appended as a separate section.
  static Future<void> exportToClipboard(
    List<DebugLogEntry> logs, {
    List<DebugTrace>? traces,
  }) async {
    final content = DebugLogExportFormatter.formatLogs(logs, traces: traces);
    await Clipboard.setData(ClipboardData(text: content));
  }

  /// Formats [logs] (and optional [traces]), writes the result to a temporary
  /// file, and opens the platform share sheet via `share_plus`.
  ///
  /// The file is written to [getTemporaryDirectory] and named with
  /// [buildFileName]. The share subject is `'DebugKit Logs Export'`.
  ///
  /// Throws if the temporary directory is unavailable or the share sheet
  /// fails. The console screen catches this and falls back to
  /// [exportToClipboard].
  ///
  /// - [logs]: log entries to include.
  /// - [traces]: optional trace entries appended as a separate section.
  static Future<void> shareLogs(
    List<DebugLogEntry> logs, {
    List<DebugTrace>? traces,
  }) async {
    final content = DebugLogExportFormatter.formatLogs(logs, traces: traces);
    final directory = await getTemporaryDirectory();
    final fileName = buildFileName(DateTime.now());
    final file = File('${directory.path}/$fileName');

    await file.writeAsString(content);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'DebugKit Logs Export',
    );
  }
}
