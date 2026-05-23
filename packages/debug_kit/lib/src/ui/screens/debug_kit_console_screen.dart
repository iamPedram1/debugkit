import 'package:flutter/material.dart';
import '../../core/controller/debug_kit_controller.dart';
import '../../core/models/debug_log_entry.dart';
import '../../utils/filtering/debug_log_filter.dart';
import '../../utils/export/debug_log_file_exporter.dart';
import '../widgets/debug_log_list.dart';
import '../widgets/debug_log_filter_bar.dart';

class DebugKitConsoleScreen extends StatefulWidget {
  const DebugKitConsoleScreen({super.key});

  @override
  State<DebugKitConsoleScreen> createState() => _DebugKitConsoleScreenState();
}

class _DebugKitConsoleScreenState extends State<DebugKitConsoleScreen> {
  DebugLogFilterState _filterState = const DebugLogFilterState();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugKitController().store,
      builder: (context, _) {
        final allLogs = DebugKitController().store.logs;
        final filteredLogs = _filterState.apply(allLogs.toList());
        final totalCount = allLogs.length;

        return Scaffold(
          backgroundColor: const Color(0xFF111111),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1A1A),
            foregroundColor: Colors.white,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DebugKit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$totalCount ${totalCount == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_all, size: 22),
                tooltip: 'Copy all to clipboard',
                onPressed: () => _copyAll(allLogs.toList()),
              ),
              IconButton(
                icon: const Icon(Icons.share, size: 22),
                tooltip: _filterState.hasActiveFilters
                    ? 'Export filtered logs'
                    : 'Export logs',
                onPressed: () => _shareLogs(
                  _filterState.hasActiveFilters
                      ? filteredLogs
                      : allLogs.toList(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, size: 22),
                tooltip: 'Clear logs',
                onPressed: () => _confirmClearLogs(),
              ),
            ],
          ),
          body: Column(
            children: [
              DebugLogFilterBar(
                state: _filterState,
                onChanged: (newState) =>
                    setState(() => _filterState = newState),
              ),
              if (_filterState.hasActiveFilters)
                _buildFilterBanner(filteredLogs.length, totalCount),
              Expanded(
                child: filteredLogs.isEmpty
                    ? _buildEmptyState(allLogs.isEmpty)
                    : DebugLogList(logs: filteredLogs),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBanner(int shown, int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: Colors.blue.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 14, color: Colors.blue[400]),
          const SizedBox(width: 6),
          Text(
            'Showing $shown / $total',
            style: TextStyle(color: Colors.blue[400], fontSize: 12),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () =>
                setState(() => _filterState = const DebugLogFilterState()),
            child: Text(
              'Clear filters',
              style: TextStyle(
                color: Colors.blue[300],
                fontSize: 12,
                decoration: TextDecoration.underline,
                decorationColor: Colors.blue[300],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool noLogsAtAll) {
    if (noLogsAtAll) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey[800]),
            const SizedBox(height: 16),
            const Text(
              'No logs yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your app and interact with it\nto see logs appear here.',
              style: TextStyle(color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          const Text(
            'No matching logs',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () =>
                setState(() => _filterState = const DebugLogFilterState()),
            icon: const Icon(Icons.filter_alt_off, size: 16),
            label: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyAll(List<dynamic> logs) async {
    await DebugLogFileExporter.exportToClipboard(logs.cast<DebugLogEntry>());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All logs copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareLogs(List<dynamic> logs) async {
    final entries = logs.cast<DebugLogEntry>();
    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No logs to export'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    try {
      await DebugLogFileExporter.shareLogs(entries);
    } catch (_) {
      try {
        await DebugLogFileExporter.exportToClipboard(entries);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Share failed — logs copied to clipboard'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export failed'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _confirmClearLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Clear all logs?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          'This will permanently remove all log entries.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              DebugKitController().store.clear();
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
