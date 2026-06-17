import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/debug_error_digest_entry.dart';
import '../widgets/debug_error_severity_badge.dart';

/// Detail view for a single [DebugErrorDigestEntry].
///
/// Shows the full sanitized message, count, first/last seen times, related
/// traces, request IDs, routes, provider names, stack trace, and health hints.
///
/// Copy summary action produces a plain-text clipboard payload suitable for
/// pasting into a bug report.
class DebugErrorDetailScreen extends StatelessWidget {
  final DebugErrorDigestEntry entry;

  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  const DebugErrorDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            DebugErrorSeverityBadge(severity: entry.severity),
            const SizedBox(width: 10),
            const Text(
              'Error Detail',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 22),
            tooltip: 'Copy error summary',
            onPressed: () => _copySummary(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Title
          _buildCard([
            _buildRow('Title', entry.title, monospace: false, selectable: true),
            const SizedBox(height: 8),
            _buildRow('Severity', entry.severity.label),
            _buildRow('Source', entry.source.label),
          ]),

          // Occurrence info
          _buildSectionHeader('Occurrences'),
          _buildCard([
            _buildRow('Count', '×${entry.count}', highlight: entry.count > 1),
            _buildRow('First seen', _dateFormat.format(entry.firstSeenAt)),
            _buildRow('Last seen', _dateFormat.format(entry.lastSeenAt)),
          ]),

          // Error message
          if (entry.latestError != null || entry.message.isNotEmpty) ...[
            _buildSectionHeader('Latest Error'),
            _buildCard([
              if (entry.latestError != null)
                _buildCodeBlock(entry.latestError!),
              if (entry.latestError == null) _buildCodeBlock(entry.message),
            ]),
          ],

          // Stack trace
          if (entry.latestStackTrace != null) ...[
            _buildSectionHeader('Stack Trace'),
            _buildCard([
              if (entry.firstUsefulStackFrame != null)
                _buildRow('First useful frame', entry.firstUsefulStackFrame!,
                    monospace: true),
              _buildCodeBlock(entry.latestStackTrace!),
            ]),
          ],

          // Related context
          if (entry.relatedTraceNames.isNotEmpty) ...[
            _buildSectionHeader('Related Traces'),
            _buildCard(
              entry.relatedTraceNames
                  .asMap()
                  .entries
                  .map((e) => _buildRow(
                      'trace ${e.key + 1}',
                      '${entry.relatedTraceIds.length > e.key ? entry.relatedTraceIds[e.key] : ''}'
                          '  ${e.value}'))
                  .toList(),
            ),
          ],

          if (entry.relatedRequestIds.isNotEmpty) ...[
            _buildSectionHeader('Related Requests'),
            _buildCard([
              _buildRow('Request IDs', entry.relatedRequestIds.join(', '),
                  monospace: true),
            ]),
          ],

          if (entry.relatedRoutes.isNotEmpty) ...[
            _buildSectionHeader('Related Routes'),
            _buildCard([
              _buildRow('Routes', entry.relatedRoutes.join('\n'),
                  monospace: true),
            ]),
          ],

          if (entry.relatedProviderNames.isNotEmpty) ...[
            _buildSectionHeader('Related Providers'),
            _buildCard(
              entry.relatedProviderNames
                  .map((name) => _buildRow('provider', name))
                  .toList(),
            ),
          ],

          // Health hints
          if (entry.healthHints.isNotEmpty) ...[
            _buildSectionHeader('Hints'),
            _buildCard(
              entry.healthHints
                  .map(
                    (hint) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 14, color: Colors.amber[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hint,
                              style: TextStyle(
                                color: Colors.amber[300],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 0, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool monospace = false,
    bool selectable = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: selectable
                ? SelectableText(
                    value,
                    style: TextStyle(
                      color:
                          highlight ? const Color(0xFFF44336) : Colors.white70,
                      fontSize: 12,
                      fontFamily: monospace ? 'monospace' : null,
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      color:
                          highlight ? const Color(0xFFF44336) : Colors.white70,
                      fontSize: 12,
                      fontFamily: monospace ? 'monospace' : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(
          color: Color(0xFFCDD5E0),
          fontSize: 11,
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Copy action
  // ---------------------------------------------------------------------------

  Future<void> _copySummary(BuildContext context) async {
    final buffer = StringBuffer();
    final df = _dateFormat;

    buffer.writeln('[${entry.severity.label}] ${entry.title}');
    buffer.writeln('Count     : ×${entry.count}');
    buffer.writeln('Source    : ${entry.source.label}');
    buffer.writeln('First seen: ${df.format(entry.firstSeenAt)}');
    buffer.writeln('Last seen : ${df.format(entry.lastSeenAt)}');

    if (entry.latestError != null) {
      buffer.writeln('Error     : ${entry.latestError}');
    }

    if (entry.firstUsefulStackFrame != null) {
      buffer.writeln('Frame     : ${entry.firstUsefulStackFrame}');
    }

    if (entry.relatedTraceNames.isNotEmpty) {
      buffer.writeln('Traces    : ${entry.relatedTraceNames.join(', ')}');
    }

    if (entry.relatedRequestIds.isNotEmpty) {
      buffer.writeln('Requests  : ${entry.relatedRequestIds.join(', ')}');
    }

    if (entry.relatedProviderNames.isNotEmpty) {
      buffer.writeln('Providers : ${entry.relatedProviderNames.join(', ')}');
    }

    if (entry.latestStackTrace != null) {
      buffer.writeln('\nStack Trace:');
      buffer.writeln(entry.latestStackTrace);
    }

    if (entry.healthHints.isNotEmpty) {
      buffer.writeln('\nHints:');
      for (final hint in entry.healthHints) {
        buffer.writeln('  - $hint');
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error summary copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
