import 'package:flutter/material.dart';
import '../../core/models/debug_log_entry.dart';
import 'debug_log_tile.dart';
import 'debug_empty_state.dart';

class DebugLogList extends StatelessWidget {
  final List<DebugLogEntry> logs;

  const DebugLogList({
    super.key,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const DebugEmptyState();
    }

    return ListView.builder(
      itemCount: logs.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        // Show newest logs at the bottom by default, but typically we want newest at top
        final entry = logs[logs.length - 1 - index];
        return DebugLogTile(entry: entry);
      },
    );
  }
}
