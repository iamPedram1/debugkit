import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/debug_log_entry.dart';
import 'debug_log_export_formatter.dart';

class DebugLogFileExporter {
  static String buildFileName(DateTime timestamp) {
    final formatted = DateFormat('yyyyMMdd-HHmmss').format(timestamp);
    return 'debugkit-logs-$formatted.txt';
  }

  static Future<void> exportToClipboard(List<DebugLogEntry> logs) async {
    final content = DebugLogExportFormatter.formatLogs(logs);
    await Clipboard.setData(ClipboardData(text: content));
  }

  static Future<void> shareLogs(List<DebugLogEntry> logs) async {
    final content = DebugLogExportFormatter.formatLogs(logs);
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
