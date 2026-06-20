import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/controller/debug_kit_controller.dart';
import '../../core/models/debug_network_endpoint_stats.dart';
import '../../core/models/debug_network_summary.dart';

/// Network tab content showing aggregate request intelligence.
class DebugNetworkSummaryScreen extends StatefulWidget {
  const DebugNetworkSummaryScreen({super.key});

  @override
  State<DebugNetworkSummaryScreen> createState() =>
      _DebugNetworkSummaryScreenState();
}

class _DebugNetworkSummaryScreenState extends State<DebugNetworkSummaryScreen> {
  DebugNetworkSummary? _cachedSummary;

  DebugNetworkSummary _getSummary() {
    _cachedSummary = DebugKitController().buildNetworkSummary();
    return _cachedSummary!;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugKitController().store,
      builder: (context, _) {
        final summary = _getSummary();
        return _buildBody(summary);
      },
    );
  }

  Widget _buildBody(DebugNetworkSummary summary) {
    if (summary.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _buildSummaryActions(summary),
        const SizedBox(height: 12),
        _buildSummaryCards(summary),
        const SizedBox(height: 12),
        _buildStatusBreakdown(summary),
        const SizedBox(height: 12),
        _buildTiming(summary),
        const SizedBox(height: 12),
        _buildEndpointSection(
          title: 'Top failing endpoints',
          emptyLabel: 'No failing endpoints',
          endpoints: summary.topFailingEndpoints,
          secondaryLineBuilder: (endpoint) =>
              'failed=${endpoint.failedCount}/${endpoint.totalCount} · lastStatus=${endpoint.lastStatusCode ?? 'unknown'}',
        ),
        const SizedBox(height: 12),
        _buildEndpointSection(
          title: 'Slowest endpoints',
          emptyLabel: 'No slow endpoints',
          endpoints: summary.slowestEndpoints,
          secondaryLineBuilder: (endpoint) =>
              'max=${endpoint.maxDurationMs ?? 'n/a'}ms · avg=${endpoint.averageDurationMs ?? 'n/a'}ms · slow=${endpoint.slowCount}/${endpoint.totalCount}',
        ),
      ],
    );
  }

  Widget _buildSummaryActions(DebugNetworkSummary summary) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Network intelligence',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copy summary',
          icon: const Icon(Icons.copy, size: 20),
          onPressed: () => _copySummary(summary),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(DebugNetworkSummary summary) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetricCard(label: 'Total', value: summary.totalRequests.toString()),
        _MetricCard(
            label: 'Completed', value: summary.completedRequests.toString()),
        _MetricCard(label: 'Failed', value: summary.failedRequests.toString()),
        _MetricCard(
            label: 'Pending', value: summary.pendingRequests.toString()),
        _MetricCard(label: 'Slow', value: summary.slowRequests.toString()),
      ],
    );
  }

  Widget _buildStatusBreakdown(DebugNetworkSummary summary) {
    return _SectionCard(
      title: 'Status breakdown',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Pill(label: '2xx', value: summary.statusBreakdown.status2xx),
          _Pill(label: '3xx', value: summary.statusBreakdown.status3xx),
          _Pill(label: '4xx', value: summary.statusBreakdown.status4xx),
          _Pill(label: '5xx', value: summary.statusBreakdown.status5xx),
          _Pill(label: 'Unknown', value: summary.statusBreakdown.statusUnknown),
        ],
      ),
    );
  }

  Widget _buildTiming(DebugNetworkSummary summary) {
    final maxDuration =
        summary.maxDurationMs != null ? '${summary.maxDurationMs}ms' : 'n/a';
    final minDuration =
        summary.minDurationMs != null ? '${summary.minDurationMs}ms' : 'n/a';
    return _SectionCard(
      title: 'Timing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Average duration: ${summary.averageDurationMs}ms',
              style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          Text('Max duration: $maxDuration',
              style: TextStyle(color: Colors.grey[300])),
          const SizedBox(height: 6),
          Text('Min duration: $minDuration',
              style: TextStyle(color: Colors.grey[300])),
          const SizedBox(height: 6),
          Text('Slow threshold: ${summary.slowRequestThresholdMs}ms',
              style: TextStyle(color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildEndpointSection({
    required String title,
    required String emptyLabel,
    required List<DebugNetworkEndpointStats> endpoints,
    required String Function(DebugNetworkEndpointStats) secondaryLineBuilder,
  }) {
    return _SectionCard(
      title: title,
      child: endpoints.isEmpty
          ? Text(emptyLabel, style: TextStyle(color: Colors.grey[500]))
          : Column(
              children: endpoints
                  .map(
                    (endpoint) => _EndpointTile(
                      endpoint: endpoint,
                      secondaryLine: secondaryLineBuilder(endpoint),
                      onCopy: () => _copyEndpoint(
                        endpoint,
                        secondaryLineBuilder(endpoint),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.network_check_outlined, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          const Text(
            'No network transactions yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Install debug_kit_dio to capture requests and see network summary data here.',
            style: TextStyle(color: Colors.grey[600], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _copySummary(DebugNetworkSummary summary) async {
    final text = StringBuffer()
      ..writeln('Network Summary')
      ..writeln('Total: ${summary.totalRequests}')
      ..writeln('Completed: ${summary.completedRequests}')
      ..writeln('Failed: ${summary.failedRequests}')
      ..writeln('Pending: ${summary.pendingRequests}')
      ..writeln('Slow: ${summary.slowRequests}')
      ..writeln(
          'Status: 2xx=${summary.statusBreakdown.status2xx}, 3xx=${summary.statusBreakdown.status3xx}, 4xx=${summary.statusBreakdown.status4xx}, 5xx=${summary.statusBreakdown.status5xx}, unknown=${summary.statusBreakdown.statusUnknown}')
      ..writeln('Average duration: ${summary.averageDurationMs}ms')
      ..writeln(
          'Max duration: ${summary.maxDurationMs != null ? '${summary.maxDurationMs}ms' : 'n/a'}');
    await Clipboard.setData(ClipboardData(text: text.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network summary copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _copyEndpoint(
    DebugNetworkEndpointStats endpoint,
    String secondaryLine,
  ) async {
    final text = '${endpoint.method} ${endpoint.path} — $secondaryLine';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Endpoint copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final int value;

  const _Pill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EndpointTile extends StatelessWidget {
  final DebugNetworkEndpointStats endpoint;
  final String secondaryLine;
  final VoidCallback onCopy;
  static final _dateFormat = DateFormat('HH:mm:ss');

  const _EndpointTile({
    required this.endpoint,
    required this.secondaryLine,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${endpoint.method} ${endpoint.path}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  secondaryLine,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                if (endpoint.lastSeenAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last seen ${_dateFormat.format(endpoint.lastSeenAt!)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
                if (endpoint.backendRequestIds.isNotEmpty ||
                    endpoint.backendCorrelationIds.isNotEmpty ||
                    endpoint.backendTraceIds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (endpoint.backendRequestIds.isNotEmpty)
                        'req=${endpoint.backendRequestIds.join(',')}',
                      if (endpoint.backendCorrelationIds.isNotEmpty)
                        'corr=${endpoint.backendCorrelationIds.join(',')}',
                      if (endpoint.backendTraceIds.isNotEmpty)
                        'trace=${endpoint.backendTraceIds.join(',')}',
                    ].join('  '),
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy endpoint',
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
