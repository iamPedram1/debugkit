import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../core/models/debug_log_entry.dart';
import 'debug_log_export_formatter.dart';

class DebugLogFileExporter {
  static Future<void> exportToClipboard(List<DebugLogEntry> logs) async {
    final content = DebugLogExportFormatter.formatLogs(logs);
    await Clipboard.setData(ClipboardData(text: content));
  }

  static Future<void> shareLogs(List<DebugLogEntry> logs) async {
    final content = DebugLogExportFormatter.formatLogs(logs);
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/debug_kit_logs_$timestamp.txt');

    await file.writeAsString(content);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'DebugKit Logs Export',
    );
  }
}
