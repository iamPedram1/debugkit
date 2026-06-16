import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/debug_trace.dart';
import '../../core/models/debug_trace_event.dart';
import '../../core/models/debug_trace_event_type.dart';
import '../../utils/trace/debug_trace_analyzer.dart';
import '../../utils/export/debug_trace_export_formatter.dart';
import '../widgets/debug_trace_status_badge.dart';

/// Shows the full timeline and metadata for a single [DebugTrace].
class DebugTraceDetailScreen extends StatelessWidget {
  final DebugTrace trace;

  const DebugTraceDetailScreen({super.key, required this.trace});

  @override
  Widget build(BuildContext context) {
    final warnings = DebugTraceAnalyzer.analyze(trace);
    final timeFormat = DateFormat('HH:mm:ss.SSS');

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trace.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              trace.id,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all, size: 22),
            tooltip: 'Copy trace summary',
            onPressed: () => _copyTrace(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Summary card
          _SectionCard(
            children: [
              _Row('Status',
                  child: DebugTraceStatusBadge(status: trace.status)),
              _Row('Started', text: timeFormat.format(trace.startedAt)),
              if (trace.endedAt != null)
                _Row('Ended', text: timeFormat.format(trace.endedAt!)),
              if (trace.durationMs != null)
                _Row('Duration', text: '${trace.durationMs}ms'),
              if (trace.parentTraceId != null)
                _Row('Parent', text: trace.parentTraceId!),
              _Row('Events', text: '${trace.events.length}'),
            ],
          ),

          // Metadata
          if (trace.metadata != null && trace.metadata!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionHeader('Metadata'),
            _SectionCard(
              children: trace.metadata!.entries
                  .map((e) => _Row(e.key, text: e.value))
                  .toList(),
            ),
          ],

          // Error summary
          if (trace.errorSummary != null) ...[
            const SizedBox(height: 12),
            const _SectionHeader('Error'),
            _SectionCard(
              children: [
                SelectableText(
                  trace.errorSummary!,
                  style: const TextStyle(
                    color: Color(0xFFF44336),
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],

          // Health warnings
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionHeader('Health Warnings'),
            _SectionCard(
              children: warnings
                  .map((w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 14, color: Color(0xFFFF9800)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                w,
                                style: const TextStyle(
                                  color: Color(0xFFFF9800),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],

          // Timeline
          if (trace.events.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionHeader('Timeline (${trace.events.length} events)'),
            ...trace.events.map((event) => _TraceEventTile(
                  event: event,
                  traceStartedAt: trace.startedAt,
                )),
          ] else ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'No events recorded',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _copyTrace(BuildContext context) async {
    final text = DebugTraceExportFormatter.formatTrace(trace);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trace summary copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[850]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? text;
  final Widget? child;

  const _Row(this.label, {this.text, this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: child ??
                Text(
                  text ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
          ),
        ],
      ),
    );
  }
}

class _TraceEventTile extends StatelessWidget {
  final DebugTraceEvent event;
  final DateTime traceStartedAt;

  const _TraceEventTile({
    required this.event,
    required this.traceStartedAt,
  });

  @override
  Widget build(BuildContext context) {
    final elapsed = event.elapsedMs(traceStartedAt);
    final color = _colorForType(event.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 2),
          bottom: BorderSide(color: Colors.grey[900]!, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  event.type.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${elapsed}ms',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (event.durationMs != null) ...[
                const SizedBox(width: 6),
                Text(
                  '${event.durationMs}ms',
                  style: TextStyle(color: Colors.grey[700], fontSize: 11),
                ),
              ],
              if (event.requestId != null) ...[
                const Spacer(),
                Text(
                  event.requestId!,
                  style: TextStyle(color: Colors.grey[700], fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            event.message,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          if (event.error != null) ...[
            const SizedBox(height: 3),
            Text(
              event.error!,
              style: const TextStyle(
                color: Color(0xFFF44336),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (event.metadata != null && event.metadata!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              event.metadata!.entries
                  .map((e) => '${e.key}=${e.value}')
                  .join('  '),
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Color _colorForType(DebugTraceEventType type) {
    return switch (type) {
      DebugTraceEventType.step => const Color(0xFF4CAF50),
      DebugTraceEventType.log => const Color(0xFF9E9E9E),
      DebugTraceEventType.network => const Color(0xFF42A5F5),
      DebugTraceEventType.navigation => const Color(0xFF26C6DA),
      DebugTraceEventType.state => const Color(0xFFAB47BC),
      DebugTraceEventType.error => const Color(0xFFF44336),
      DebugTraceEventType.custom => const Color(0xFFFF9800),
    };
  }
}
