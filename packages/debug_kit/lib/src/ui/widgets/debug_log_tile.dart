import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_log_level.dart';
import '../../core/models/debug_log_source.dart';

/// A single log entry tile with expand-on-tap and long-press-to-copy.
///
/// When [DebugLogEntry.repeatCount] is greater than 1, a compact `×N` repeat
/// badge is displayed in the header row. Expanded view shows first-seen and
/// last-seen timestamps alongside the repeat count.
class DebugLogTile extends StatefulWidget {
  final DebugLogEntry entry;

  const DebugLogTile({
    super.key,
    required this.entry,
  });

  @override
  State<DebugLogTile> createState() => _DebugLogTileState();
}

class _DebugLogTileState extends State<DebugLogTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final levelColor = _getLevelColor(entry.level);
    final time = DateFormat('HH:mm:ss').format(entry.timestamp);
    final isRepeated = entry.repeatCount > 1;

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      onLongPress: () => _copyToClipboard(context, _buildCopyText(entry)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[850]!, width: 1),
            left: BorderSide(color: levelColor, width: 3),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: level badge · source badge · time · repeat badge · chevron
            Row(
              children: [
                _Badge(label: entry.level.label, color: levelColor),
                const SizedBox(width: 5),
                _Badge(
                  label: entry.source.label,
                  color: _getSourceColor(entry.source),
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                // Repeat badge — shown only when collapsed (count > 1)
                if (isRepeated && !_isExpanded) ...[
                  _RepeatBadge(count: entry.repeatCount),
                  const SizedBox(width: 6),
                ],
                if (!isRepeated && entry.requestId != null)
                  Flexible(
                    child: Text(
                      entry.requestId!,
                      style: TextStyle(color: Colors.grey[700], fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey[700],
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Message
            Text(
              entry.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            if (entry.location != null) ...[
              const SizedBox(height: 2),
              Text(
                entry.location!,
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
            // Expanded detail blocks
            if (_isExpanded) ...[
              const SizedBox(height: 10),
              // Repeat info block (shown when grouped)
              if (isRepeated) ...[
                _DetailBlock(
                  title: 'Repeat',
                  content: '×${entry.repeatCount}',
                  color: const Color(0xFF64B5F6),
                ),
                _DetailBlock(
                  title: 'First seen',
                  content: DateFormat('yyyy-MM-dd HH:mm:ss.SSS')
                      .format(entry.timestamp),
                  color: Colors.grey[500],
                ),
                if (entry.lastSeenAt != null)
                  _DetailBlock(
                    title: 'Last seen',
                    content: DateFormat('yyyy-MM-dd HH:mm:ss.SSS')
                        .format(entry.lastSeenAt!),
                    color: Colors.grey[500],
                  ),
              ] else
                _DetailBlock(
                  title: 'Timestamp',
                  content: DateFormat('yyyy-MM-dd HH:mm:ss.SSS')
                      .format(entry.timestamp),
                  color: Colors.grey[500],
                ),
              if (entry.error != null)
                _DetailBlock(
                  title: 'Error',
                  content: entry.error!,
                  color: Colors.red[400],
                ),
              if (entry.metadata != null && entry.metadata!.isNotEmpty)
                _DetailBlock(
                  title: 'Metadata',
                  content: entry.metadata!.entries
                      .map((e) => '  ${e.key}: ${e.value}')
                      .join('\n'),
                ),
              if (entry.requestId != null)
                _DetailBlock(
                  title: 'Request ID',
                  content: entry.requestId!,
                  color: Colors.grey[600],
                ),
              if (entry.payloadPreview != null)
                _DetailBlock(
                  title: 'Request Payload',
                  content: entry.payloadPreview!,
                ),
              if (entry.responsePreview != null)
                _DetailBlock(
                  title: 'Response',
                  content: entry.responsePreview!,
                  color: Colors.cyan[300],
                ),
              if (entry.stackTrace != null)
                _DetailBlock(
                  title: 'Stack Trace',
                  content: entry.stackTrace!,
                  color: Colors.orange[400],
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the clipboard text, including repeat info when grouped.
  String _buildCopyText(DebugLogEntry entry) {
    if (entry.repeatCount > 1) {
      return '×${entry.repeatCount} ${entry.message}';
    }
    return entry.message;
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Color _getLevelColor(DebugLogLevel level) {
    return switch (level) {
      DebugLogLevel.debug => const Color(0xFF9E9E9E),
      DebugLogLevel.info => const Color(0xFF4CAF50),
      DebugLogLevel.warning => const Color(0xFFFF9800),
      DebugLogLevel.error => const Color(0xFFF44336),
    };
  }

  Color _getSourceColor(DebugLogSource source) {
    return switch (source) {
      DebugLogSource.app => const Color(0xFF66BB6A),
      DebugLogSource.dio => const Color(0xFF42A5F5),
      DebugLogSource.riverpod => const Color(0xFFAB47BC),
      DebugLogSource.router => const Color(0xFF26C6DA),
      DebugLogSource.userAction => const Color(0xFFFF7043),
    };
  }
}

// ---------------------------------------------------------------------------
// Repeat badge
// ---------------------------------------------------------------------------

/// Compact `×N` badge shown on grouped log entries.
class _RepeatBadge extends StatelessWidget {
  final int count;

  const _RepeatBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF64B5F6).withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        '×$count',
        style: const TextStyle(
          color: Color(0xFF64B5F6),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared private widgets
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String title;
  final String content;
  final Color? color;

  const _DetailBlock({
    required this.title,
    required this.content,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color ?? Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.grey[850]!,
                width: 1,
              ),
            ),
            child: SelectableText(
              content,
              style: TextStyle(
                color: color ?? Colors.grey[300],
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
