import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_log_level.dart';
import '../../core/models/debug_log_source.dart';

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
    final color = _getLevelColor(entry.level);
    final time = DateFormat('HH:mm:ss').format(entry.timestamp);

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[900]!, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Badge(label: entry.level.label, color: color),
                const SizedBox(width: 4),
                _Badge(
                    label: entry.source.label,
                    color: _getSourceColor(entry.source)),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Spacer(),
                if (entry.requestId != null)
                  Text(
                    entry.requestId!,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            if (entry.location != null)
              Text(
                entry.location!,
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              if (entry.error != null)
                _DetailBlock(
                    title: 'Error', content: entry.error!, color: Colors.red),
              if (entry.metadata != null && entry.metadata!.isNotEmpty)
                _DetailBlock(
                  title: 'Metadata',
                  content: entry.metadata!.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                ),
              if (entry.payloadPreview != null)
                _DetailBlock(title: 'Payload', content: entry.payloadPreview!),
              if (entry.responsePreview != null)
                _DetailBlock(
                    title: 'Response', content: entry.responsePreview!),
              if (entry.stackTrace != null)
                _DetailBlock(title: 'Stack Trace', content: entry.stackTrace!),
            ],
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(DebugLogLevel level) {
    return switch (level) {
      DebugLogLevel.debug => Colors.grey,
      DebugLogLevel.info => Colors.green,
      DebugLogLevel.warning => Colors.orange,
      DebugLogLevel.error => Colors.red,
    };
  }

  Color _getSourceColor(DebugLogSource source) {
    return switch (source) {
      DebugLogSource.app => Colors.green[700]!,
      DebugLogSource.dio => Colors.blue,
      DebugLogSource.riverpod => Colors.purple,
      DebugLogSource.router => Colors.cyan,
      DebugLogSource.userAction => Colors.orange[700]!,
    };
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String title;
  final String content;
  final Color? color;

  const _DetailBlock({required this.title, required this.content, this.color});

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
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              content,
              style: TextStyle(
                color: color ?? Colors.grey[300],
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
