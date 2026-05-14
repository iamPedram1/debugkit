import 'package:flutter/material.dart';
import '../../core/controller/debug_kit_controller.dart';
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'DebugKit Console',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy all to clipboard',
            onPressed: () => _copyAll(),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share logs',
            onPressed: () => _shareLogs(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear logs',
            onPressed: () => _clearLogs(),
          ),
        ],
      ),
      body: Column(
        children: [
          DebugLogFilterBar(
            state: _filterState,
            onChanged: (newState) => setState(() => _filterState = newState),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: DebugKitController().store,
              builder: (context, _) {
                final allLogs = DebugKitController().store.logs;
                final filteredLogs = _filterState.apply(allLogs.toList());

                return Column(
                  children: [
                    if (_filterState.hasActiveFilters)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        color: Colors.blue.withValues(alpha: 0.1),
                        child: Row(
                          children: [
                            Text(
                              'Showing ${filteredLogs.length} / ${allLogs.length} logs',
                              style: const TextStyle(
                                  color: Colors.blue, fontSize: 12),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => setState(() =>
                                  _filterState = const DebugLogFilterState()),
                              child: const Text('Clear Filters',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: DebugLogList(logs: filteredLogs),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyAll() async {
    final logs = DebugKitController().store.logs;
    await DebugLogFileExporter.exportToClipboard(logs.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs copied to clipboard')),
      );
    }
  }

  Future<void> _shareLogs() async {
    final logs = DebugKitController().store.logs;
    await DebugLogFileExporter.shareLogs(logs.toList());
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Clear Logs', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to clear all logs?',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              DebugKitController().store.clear();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
