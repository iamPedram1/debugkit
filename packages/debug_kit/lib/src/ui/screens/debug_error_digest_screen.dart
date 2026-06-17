import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/controller/debug_kit_controller.dart';
import '../../core/models/debug_error_digest.dart';
import '../../core/models/debug_error_digest_entry.dart';
import '../../core/models/debug_error_digest_severity.dart';
import '../widgets/debug_error_severity_badge.dart';
import 'debug_error_detail_screen.dart';

/// The Errors tab content — shows the [DebugErrorDigest] built on demand.
///
/// Rebuilds whenever the log or trace stores notify listeners. The digest is
/// computed once per store change (not per frame) by caching the result and
/// invalidating it in [ListenableBuilder].
///
/// Mobile-first dark theme, consistent with the existing Logs and Traces tabs.
class DebugErrorDigestScreen extends StatefulWidget {
  const DebugErrorDigestScreen({super.key});

  @override
  State<DebugErrorDigestScreen> createState() => _DebugErrorDigestScreenState();
}

class _DebugErrorDigestScreenState extends State<DebugErrorDigestScreen> {
  DebugErrorDigest? _cachedDigest;

  /// Rebuild the digest only when store notifications arrive, not on every
  /// widget rebuild.
  DebugErrorDigest _getDigest() {
    _cachedDigest = DebugKitController().buildErrorDigest();
    return _cachedDigest!;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        DebugKitController().store,
        DebugKitController().traceStore,
      ]),
      builder: (context, _) {
        final digest = _getDigest();
        return _buildBody(digest);
      },
    );
  }

  Widget _buildBody(DebugErrorDigest digest) {
    if (digest.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryBar(digest),
        Expanded(
          child: ListView.builder(
            itemCount: digest.entries.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              return _ErrorDigestTile(entry: digest.entries[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar(DebugErrorDigest digest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF1A1A1A),
      child: Row(
        children: [
          _SummaryChip(
            label: '${digest.uniqueErrors} unique',
            color: const Color(0xFFF44336),
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: '${digest.totalErrors} total',
            color: const Color(0xFFFF9800),
          ),
          if (digest.failedNetworkCount > 0) ...[
            const SizedBox(width: 8),
            _SummaryChip(
              label: '${digest.failedNetworkCount} network',
              color: const Color(0xFF9C27B0),
            ),
          ],
          if (digest.failedTraceCount > 0) ...[
            const SizedBox(width: 8),
            _SummaryChip(
              label: '${digest.failedTraceCount} traces',
              color: const Color(0xFF607D8B),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          const Text(
            'No errors detected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Error logs, failed traces, and provider\nfailures will appear here.',
            style: TextStyle(color: Colors.grey[600], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _ErrorDigestTile extends StatelessWidget {
  final DebugErrorDigestEntry entry;
  static final _timeFormat = DateFormat('HH:mm:ss');

  const _ErrorDigestTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DebugErrorDetailScreen(entry: entry),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[850]!, width: 1),
            left: BorderSide(
              color: _severityColor(entry.severity),
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: badge + title + count badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DebugErrorSeverityBadge(severity: entry.severity),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _CountBadge(count: entry.count),
              ],
            ),
            const SizedBox(height: 5),
            // Row 2: source + time + stack frame
            Row(
              children: [
                _SourceChip(source: entry.source.label),
                const SizedBox(width: 8),
                Text(
                  _timeFormat.format(entry.lastSeenAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                if (entry.firstUsefulStackFrame != null) ...[
                  Text(
                    '  ·  ${entry.firstUsefulStackFrame}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            // Row 3: related context chips
            if (entry.hasRelatedContext) ...[
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (entry.relatedTraceNames.isNotEmpty)
                    _ContextChip(
                      icon: Icons.timeline,
                      label: entry.relatedTraceNames.take(2).join(', '),
                    ),
                  if (entry.relatedProviderNames.isNotEmpty)
                    _ContextChip(
                      icon: Icons.settings_ethernet,
                      label: entry.relatedProviderNames.first,
                    ),
                  if (entry.relatedRequestIds.isNotEmpty)
                    _ContextChip(
                      icon: Icons.cloud_outlined,
                      label:
                          '${entry.relatedRequestIds.length} request${entry.relatedRequestIds.length == 1 ? '' : 's'}',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _severityColor(DebugErrorDigestSeverity severity) {
    return switch (severity) {
      DebugErrorDigestSeverity.fatal => const Color(0xFFFF1744),
      DebugErrorDigestSeverity.error => const Color(0xFFF44336),
      DebugErrorDigestSeverity.warning => const Color(0xFFFF9800),
    };
  }
}

// ---------------------------------------------------------------------------
// Small reusable widgets
// ---------------------------------------------------------------------------

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF44336).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFF44336).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        '×$count',
        style: const TextStyle(
          color: Color(0xFFF44336),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String source;
  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        source,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContextChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey[600]),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
