import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/controller/debug_kit_controller.dart';
import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_state_event.dart';
import '../../core/models/debug_trace.dart';
import '../../core/models/debug_network_summary.dart';
import '../../utils/filtering/debug_log_filter.dart';
import '../../utils/export/debug_log_file_exporter.dart';
import '../../utils/network/debug_network_summary_builder.dart';
import '../../utils/trace/debug_trace_analyzer.dart';
import '../widgets/debug_log_list.dart';
import '../widgets/debug_log_filter_bar.dart';
import '../widgets/debug_trace_status_badge.dart';
import 'debug_trace_detail_screen.dart';
import 'debug_error_digest_screen.dart';
import 'debug_network_inspector_screen.dart';
import 'debug_state_inspector_screen.dart';

class DebugKitConsoleScreen extends StatefulWidget {
  const DebugKitConsoleScreen({super.key});

  @override
  State<DebugKitConsoleScreen> createState() => _DebugKitConsoleScreenState();
}

class _DebugKitConsoleScreenState extends State<DebugKitConsoleScreen>
    with SingleTickerProviderStateMixin {
  DebugLogFilterState _filterState = const DebugLogFilterState();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        DebugKitController().store,
        DebugKitController().traceStore,
        DebugKitController().stateStore,
      ]),
      builder: (context, _) {
        final allLogs = DebugKitController().store.logs;
        final filteredLogs = _filterState.apply(allLogs.toList());
        final totalCount = allLogs.length;
        final allTraces = DebugKitController().traceStore.traces;
        final networkSummary = DebugKitController().buildNetworkSummary();

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
                  '$totalCount ${totalCount == 1 ? 'entry' : 'entries'}'
                  '  ·  ${DebugKitController().stateStore.events.length} state'
                  '  ·  ${allTraces.length} ${allTraces.length == 1 ? 'trace' : 'traces'}'
                  '  ·  ${networkSummary.totalRequests} network',
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
                onPressed: () => _copyAll(allLogs.toList(), allTraces.toList()),
              ),
              IconButton(
                icon: const Icon(Icons.share, size: 22),
                tooltip: 'Export selected sections',
                onPressed: () => _showExportDialog(
                  _filterState.hasActiveFilters
                      ? filteredLogs
                      : allLogs.toList(),
                  allTraces.toList(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, size: 22),
                tooltip: 'Clear logs',
                onPressed: () => _confirmClearLogs(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.blueAccent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Logs'),
                Tab(text: 'State'),
                Tab(text: 'Network'),
                Tab(text: 'Traces'),
                Tab(text: 'Errors'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            // Tab swiping is disabled so interactive debug panels such as the
            // Network timeline can own horizontal drag gestures.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // --- Logs tab ---
              Column(
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
                        ? _buildLogsEmptyState(allLogs.isEmpty)
                        : DebugLogList(logs: filteredLogs),
                  ),
                ],
              ),

              // --- State tab ---
              const DebugStateInspectorScreen(),

              // --- Network tab ---
              const DebugNetworkSummaryScreen(),

              // --- Traces tab ---
              _buildTracesTab(allTraces.toList()),

              // --- Errors tab ---
              const DebugErrorDigestScreen(),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Traces tab
  // ---------------------------------------------------------------------------

  Widget _buildTracesTab(List<DebugTrace> traces) {
    if (traces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline_outlined, size: 64, color: Colors.grey[800]),
            const SizedBox(height: 16),
            const Text(
              'No traces yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use DebugKit.trace.run() or\nDebugKit.trace.start() to record traces.',
              style: TextStyle(color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show newest traces first
    final reversed = traces.reversed.toList();

    return ListView.builder(
      itemCount: reversed.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        return _TraceListTile(trace: reversed[index]);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Logs tab helpers
  // ---------------------------------------------------------------------------

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

  Widget _buildLogsEmptyState(bool noLogsAtAll) {
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

  // ---------------------------------------------------------------------------
  // Export actions
  // ---------------------------------------------------------------------------

  Future<void> _copyAll(
      List<DebugLogEntry> logs, List<DebugTrace> traces) async {
    final digest = DebugKitController().buildErrorDigest();
    final summary = DebugNetworkSummaryBuilder.build(
      logs,
      slowRequestThresholdMs:
          DebugKitController().config.slowRequestThresholdMs,
    );
    final stateEvents = DebugKitController().stateStore.events.toList();
    await DebugLogFileExporter.exportToClipboard(logs,
        stateEvents: stateEvents,
        traces: traces,
        digest: digest.isEmpty ? null : digest,
        networkSummary: summary.isEmpty ? null : summary);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected export copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareLogs(
    List<DebugLogEntry> logs,
    List<DebugTrace> traces, {
    required List<DebugStateEvent> stateEvents,
    DebugNetworkSummary? networkSummary,
    bool includeLogs = true,
    bool includeStateEvents = true,
    bool includeTraces = true,
    bool includeNetworkSummary = true,
    bool includeNetworkTransactions = true,
    bool includeDigest = true,
  }) async {
    final digest = DebugKitController().buildErrorDigest();
    final hasSelectedContent = (includeLogs && logs.isNotEmpty) ||
        (includeStateEvents && stateEvents.isNotEmpty) ||
        (includeTraces && traces.isNotEmpty) ||
        (includeNetworkSummary &&
            networkSummary != null &&
            !networkSummary.isEmpty) ||
        (includeNetworkTransactions && logs.isNotEmpty) ||
        (includeDigest && !digest.isEmpty);

    if (!hasSelectedContent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No exportable content selected'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    try {
      await DebugLogFileExporter.shareLogs(logs,
          stateEvents: stateEvents,
          traces: traces,
          digest: digest.isEmpty ? null : digest,
          networkSummary: networkSummary,
          includeLogs: includeLogs,
          includeStateEvents: includeStateEvents,
          includeTraces: includeTraces,
          includeNetworkSummary: includeNetworkSummary,
          includeNetworkTransactions: includeNetworkTransactions,
          includeDigest: includeDigest);
    } catch (_) {
      try {
        await DebugLogFileExporter.exportToClipboard(logs,
            stateEvents: stateEvents,
            traces: traces,
            digest: digest.isEmpty ? null : digest,
            networkSummary: networkSummary,
            includeLogs: includeLogs,
            includeStateEvents: includeStateEvents,
            includeTraces: includeTraces,
            includeNetworkSummary: includeNetworkSummary,
            includeNetworkTransactions: includeNetworkTransactions,
            includeDigest: includeDigest);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Share failed — export copied to clipboard'),
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

  Future<void> _showExportDialog(
    List<DebugLogEntry> logs,
    List<DebugTrace> traces,
  ) async {
    final stateEvents = DebugKitController().stateStore.events.toList();
    final digest = DebugKitController().buildErrorDigest();
    final summary = DebugNetworkSummaryBuilder.build(
      logs,
      slowRequestThresholdMs:
          DebugKitController().config.slowRequestThresholdMs,
    );
    final selection = await showDialog<_ExportSelection>(
      context: context,
      builder: (ctx) => const _ExportDialog(
        initialSelection: _ExportSelection(
          includeLogs: true,
          includeStateEvents: true,
          includeTraces: true,
          includeNetworkSummary: true,
          includeNetworkTransactions: true,
          includeDigest: true,
        ),
      ),
    );

    if (selection == null) return;

    await _shareLogs(
      logs,
      traces,
      stateEvents: stateEvents,
      networkSummary: summary.isEmpty ? null : summary,
      includeLogs: selection.includeLogs,
      includeStateEvents: selection.includeStateEvents,
      includeTraces: selection.includeTraces,
      includeNetworkSummary: selection.includeNetworkSummary,
      includeNetworkTransactions: selection.includeNetworkTransactions,
      includeDigest: selection.includeDigest && !digest.isEmpty,
    );
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

// ---------------------------------------------------------------------------
// Trace list tile
// ---------------------------------------------------------------------------

class _TraceListTile extends StatelessWidget {
  final DebugTrace trace;

  const _TraceListTile({required this.trace});

  @override
  Widget build(BuildContext context) {
    final warnings = DebugTraceAnalyzer.analyze(trace);
    final hasWarnings = warnings.isNotEmpty;
    final timeFormat = DateFormat('HH:mm:ss');

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DebugTraceDetailScreen(trace: trace),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[850]!, width: 1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DebugTraceStatusBadge(status: trace.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trace.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasWarnings)
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFFF9800)),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  timeFormat.format(trace.startedAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                if (trace.durationMs != null) ...[
                  Text(
                    '  ·  ${trace.durationMs}ms',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
                Text(
                  '  ·  ${trace.events.length} events',
                  style: TextStyle(color: Colors.grey[700], fontSize: 11),
                ),
                if (trace.parentTraceId != null) ...[
                  Text(
                    '  ·  nested',
                    style: TextStyle(color: Colors.grey[700], fontSize: 11),
                  ),
                ],
              ],
            ),
            if (trace.errorSummary != null) ...[
              const SizedBox(height: 4),
              Text(
                trace.errorSummary!,
                style: const TextStyle(
                  color: Color(0xFFF44336),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExportSelection {
  final bool includeLogs;
  final bool includeStateEvents;
  final bool includeTraces;
  final bool includeNetworkSummary;
  final bool includeNetworkTransactions;
  final bool includeDigest;

  const _ExportSelection({
    required this.includeLogs,
    required this.includeStateEvents,
    required this.includeTraces,
    required this.includeNetworkSummary,
    required this.includeNetworkTransactions,
    required this.includeDigest,
  });

  _ExportSelection copyWith({
    bool? includeLogs,
    bool? includeStateEvents,
    bool? includeTraces,
    bool? includeNetworkSummary,
    bool? includeNetworkTransactions,
    bool? includeDigest,
  }) {
    return _ExportSelection(
      includeLogs: includeLogs ?? this.includeLogs,
      includeStateEvents: includeStateEvents ?? this.includeStateEvents,
      includeTraces: includeTraces ?? this.includeTraces,
      includeNetworkSummary:
          includeNetworkSummary ?? this.includeNetworkSummary,
      includeNetworkTransactions:
          includeNetworkTransactions ?? this.includeNetworkTransactions,
      includeDigest: includeDigest ?? this.includeDigest,
    );
  }
}

class _ExportDialog extends StatefulWidget {
  final _ExportSelection initialSelection;

  const _ExportDialog({required this.initialSelection});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late _ExportSelection _selection;

  @override
  void initState() {
    super.initState();
    _selection = widget.initialSelection;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF222222),
      title: const Text(
        'Export sections',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCheck('Logs', _selection.includeLogs, (value) {
              setState(
                  () => _selection = _selection.copyWith(includeLogs: value));
            }),
            _buildCheck('State', _selection.includeStateEvents, (value) {
              setState(() =>
                  _selection = _selection.copyWith(includeStateEvents: value));
            }),
            _buildCheck('Traces', _selection.includeTraces, (value) {
              setState(
                  () => _selection = _selection.copyWith(includeTraces: value));
            }),
            _buildCheck('Network summary', _selection.includeNetworkSummary,
                (value) {
              setState(() => _selection =
                  _selection.copyWith(includeNetworkSummary: value));
            }),
            _buildCheck(
                'Network requests', _selection.includeNetworkTransactions,
                (value) {
              setState(() => _selection = _selection.copyWith(
                    includeNetworkTransactions: value,
                  ));
            }),
            _buildCheck('Error digest', _selection.includeDigest, (value) {
              setState(
                  () => _selection = _selection.copyWith(includeDigest: value));
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selection),
          child: const Text('Export'),
        ),
      ],
    );
  }

  Widget _buildCheck(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      value: value,
      onChanged: (next) => onChanged(next ?? false),
    );
  }
}
