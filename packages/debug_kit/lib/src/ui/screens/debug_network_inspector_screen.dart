import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/controller/debug_kit_controller.dart';
import '../../core/models/debug_network_filter_state.dart';
import '../../core/models/debug_network_sort_option.dart';
import '../../core/models/debug_network_status_family.dart';
import '../../core/models/debug_network_summary.dart';
import '../../core/models/debug_network_transaction.dart';
import '../../core/models/debug_network_transaction_phase.dart';
import '../../utils/filtering/debug_network_filter.dart';
import '../../utils/network/debug_network_summary_builder.dart';
import '../../utils/network/debug_network_waterfall.dart';

/// Chrome-like network inspector tab for DebugKit.
class DebugNetworkSummaryScreen extends StatefulWidget {
  const DebugNetworkSummaryScreen({super.key});

  @override
  State<DebugNetworkSummaryScreen> createState() =>
      _DebugNetworkSummaryScreenState();
}

class _DebugNetworkSummaryScreenState extends State<DebugNetworkSummaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  DebugNetworkFilterState _filterState = const DebugNetworkFilterState();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugKitController().store,
      builder: (context, _) {
        final controller = DebugKitController();
        final allTransactions = controller.buildNetworkTransactions();
        final effectiveFilterState = _filterState.copyWith(
          slowThresholdMs: controller.config.slowRequestThresholdMs,
        );
        final filteredTransactions =
            applyNetworkFiltersAndSort(allTransactions, effectiveFilterState);
        final visibleSummary = DebugNetworkSummaryBuilder.buildFromTransactions(
          filteredTransactions,
          slowRequestThresholdMs: controller.config.slowRequestThresholdMs,
        );
        final waterfall = DebugNetworkWaterfallMetrics.fromTransactions(
          filteredTransactions,
        );

        return SafeArea(
          top: false,
          child: Column(
            children: [
              _buildToolbar(context, controller),
              _buildFilterChips(),
              const SizedBox(height: 10),
              _buildSummaryStrip(visibleSummary),
              const SizedBox(height: 10),
              Expanded(
                child: filteredTransactions.isEmpty
                    ? _buildEmptyState(allTransactions.isEmpty)
                    : _buildRequestList(
                        context,
                        filteredTransactions,
                        waterfall,
                        controller.config.slowRequestThresholdMs,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, DebugKitController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _filterState = _filterState.copyWith(
                        searchQuery: value,
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Clear network',
                onPressed: () => controller.clearNetworkTransactions(),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
              PopupMenuButton<DebugNetworkSortOption>(
                tooltip: 'Sort',
                initialValue: _filterState.sortOption,
                onSelected: (value) {
                  setState(() {
                    _filterState = _filterState.copyWith(sortOption: value);
                  });
                },
                itemBuilder: (context) => [
                  for (final option in DebugNetworkSortOption.values)
                    PopupMenuItem(
                      value: option,
                      child: Text(option.label),
                    ),
                ],
                icon: const Icon(Icons.sort),
              ),
            ],
          ),
          if (_filterState.hasActiveFilters) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Filters active',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];
    const statusFilters = [
      DebugNetworkStatusFilter.all,
      DebugNetworkStatusFilter.pending,
      DebugNetworkStatusFilter.failed,
      DebugNetworkStatusFilter.twoXX,
      DebugNetworkStatusFilter.threeXX,
      DebugNetworkStatusFilter.fourXX,
      DebugNetworkStatusFilter.fiveXX,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final method in methods) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _filterState.methods.contains(method),
                      label: Text(method),
                      onSelected: (selected) => _toggleMethod(method, selected),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final status in statusFilters) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: status == DebugNetworkStatusFilter.all
                          ? _filterState.statuses.isEmpty
                          : _filterState.statuses.contains(status),
                      label: Text(status.label),
                      onSelected: (selected) => _toggleStatus(status, selected),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _filterState.slowOnly,
                    label: const Text('Slow'),
                    onSelected: (selected) {
                      setState(() {
                        _filterState =
                            _filterState.copyWith(slowOnly: selected);
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _filterState.errorsOnly,
                    label: const Text('Errors'),
                    onSelected: (selected) {
                      setState(() {
                        _filterState =
                            _filterState.copyWith(errorsOnly: selected);
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _filterState.pendingOnly,
                    label: const Text('Pending'),
                    onSelected: (selected) {
                      setState(() {
                        _filterState =
                            _filterState.copyWith(pendingOnly: selected);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(DebugNetworkSummary summary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SummaryChip(label: 'Total', value: summary.totalRequests),
          _SummaryChip(
            label: 'Failed',
            value: summary.failedRequests,
            accent: const Color(0xFFF44336),
          ),
          _SummaryChip(
            label: 'Pending',
            value: summary.pendingRequests,
            accent: const Color(0xFFFFC107),
          ),
          _SummaryChip(
            label: 'Slow',
            value: summary.slowRequests,
            accent: const Color(0xFF03DAC6),
          ),
          _SummaryChip(
            label: 'Avg',
            value: summary.averageDurationMs,
            suffix: 'ms',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool noRequestsAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.network_check_outlined,
              size: 64,
              color: Colors.grey[800],
            ),
            const SizedBox(height: 16),
            Text(
              noRequestsAtAll ? 'No network requests yet' : 'No matches found',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noRequestsAtAll
                  ? 'Install debug_kit_dio to capture requests automatically.\nThe Network tab will then show a request list, details, and timing.'
                  : 'Try adjusting search, chips, or sort order.',
              style: TextStyle(color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (!noRequestsAtAll) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off, size: 16),
                label: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestList(
    BuildContext context,
    List<DebugNetworkTransaction> transactions,
    DebugNetworkWaterfallMetrics waterfall,
    int slowThresholdMs,
  ) {
    final rowById = {
      for (final row in waterfall.rows) row.transaction.logEntryId: row,
    };

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final row = rowById[transaction.logEntryId];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _NetworkTransactionTile(
            transaction: transaction,
            row: row,
            slowThresholdMs: slowThresholdMs,
            onTap: () => _openDetails(context, transaction),
          ),
        );
      },
    );
  }

  void _toggleMethod(String method, bool selected) {
    setState(() {
      final methods = {..._filterState.methods};
      if (selected) {
        methods.add(method);
      } else {
        methods.remove(method);
      }
      _filterState = _filterState.copyWith(methods: methods);
    });
  }

  void _toggleStatus(DebugNetworkStatusFilter status, bool selected) {
    setState(() {
      if (status == DebugNetworkStatusFilter.all) {
        _filterState = _filterState.copyWith(statuses: const {});
        return;
      }
      final statuses = {..._filterState.statuses};
      if (selected) {
        statuses.add(status);
      } else {
        statuses.remove(status);
      }
      _filterState = _filterState.copyWith(statuses: statuses);
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _filterState = const DebugNetworkFilterState();
    });
  }

  Future<void> _openDetails(
    BuildContext context,
    DebugNetworkTransaction transaction,
  ) async {
    final media = MediaQuery.sizeOf(context);
    final sheet = _TransactionDetailSheet(transaction: transaction);

    if (media.width >= 720) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: const Color(0xFF161616),
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
            child: sheet,
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: sheet,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search requests, IDs, errors, trace...',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        prefixIcon: const Icon(Icons.search, size: 18),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[850]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[850]!),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF4FC3F7)),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int value;
  final String? suffix;
  final Color? accent;

  const _SummaryChip({
    required this.label,
    required this.value,
    this.suffix,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent ?? Colors.grey[850]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          const SizedBox(width: 8),
          Text(
            suffix == null ? '$value' : '$value$suffix',
            style: TextStyle(
              color: accent ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkTransactionTile extends StatelessWidget {
  final DebugNetworkTransaction transaction;
  final DebugNetworkWaterfallRow? row;
  final int slowThresholdMs;
  final VoidCallback onTap;

  const _NetworkTransactionTile({
    required this.transaction,
    required this.row,
    required this.slowThresholdMs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSlow = transaction.isSlow(slowThresholdMs);
    final showError = transaction.isFailed || transaction.errorMessage != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[850]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MethodBadge(method: transaction.method),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.displayPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatusBadge(transaction: transaction),
                          _PhaseBadge(phase: transaction.phase),
                          if (transaction.requestId != null)
                            _MiniChip(text: transaction.requestId!),
                          if (transaction.backendCorrelationId != null)
                            _MiniChip(text: transaction.backendCorrelationId!),
                          _MiniChip(text: transaction.durationLabel),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      transaction.startedAtLabel,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      transaction.durationLabel,
                      style: TextStyle(
                        color: isSlow ? const Color(0xFFFFC107) : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (row != null)
              _WaterfallBar(
                row: row!,
                color: showError
                    ? const Color(0xFFF44336)
                    : isSlow
                        ? const Color(0xFFFFC107)
                        : const Color(0xFF4FC3F7),
              )
            else
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF202020),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            if (showError || isSlow) ...[
              const SizedBox(height: 8),
              Text(
                showError
                    ? (transaction.errorSummary ?? 'Request failed')
                    : 'Slow request',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: showError
                      ? const Color(0xFFF44336)
                      : const Color(0xFFFFC107),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  final String method;

  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      alignment: Alignment.center,
      child: Text(
        method,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DebugNetworkTransaction transaction;

  const _StatusBadge({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final color = switch (transaction.statusFamily) {
      DebugNetworkStatusFamily.twoXX => const Color(0xFF4CAF50),
      DebugNetworkStatusFamily.threeXX => const Color(0xFF64B5F6),
      DebugNetworkStatusFamily.fourXX => const Color(0xFFFFB74D),
      DebugNetworkStatusFamily.fiveXX => const Color(0xFFF44336),
      DebugNetworkStatusFamily.unknown => Colors.grey,
    };
    return _MiniChip(text: transaction.statusLabel, color: color);
  }
}

class _PhaseBadge extends StatelessWidget {
  final DebugNetworkTransactionPhase phase;

  const _PhaseBadge({required this.phase});

  @override
  Widget build(BuildContext context) {
    final color = switch (phase) {
      DebugNetworkTransactionPhase.completed => const Color(0xFF4CAF50),
      DebugNetworkTransactionPhase.pending => const Color(0xFFFFC107),
      DebugNetworkTransactionPhase.failed => const Color(0xFFF44336),
      DebugNetworkTransactionPhase.cancelled => const Color(0xFF9E9E9E),
      DebugNetworkTransactionPhase.unknown => Colors.grey,
    };
    return _MiniChip(text: phase.label, color: color);
  }
}

class _MiniChip extends StatelessWidget {
  final String text;
  final Color? color;

  const _MiniChip({
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color ?? Colors.grey[850]!),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.grey[300],
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WaterfallBar extends StatelessWidget {
  final DebugNetworkWaterfallRow row;
  final Color color;

  const _WaterfallBar({
    required this.row,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final left = width * row.barStartFraction;
              final barWidth =
                  (width * row.barWidthFraction).clamp(6.0, width).toDouble();
              return Padding(
                padding: EdgeInsets.only(left: left),
                child: Container(
                  width: barWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: row.isPending
                          ? [
                              color.withValues(alpha: 0.45),
                              color.withValues(alpha: 0.8),
                            ]
                          : [
                              color.withValues(alpha: 0.65),
                              color,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TransactionDetailSheet extends StatelessWidget {
  final DebugNetworkTransaction transaction;

  const _TransactionDetailSheet({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          _DetailHeader(transaction: transaction),
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Headers'),
              Tab(text: 'Request'),
              Tab(text: 'Response'),
              Tab(text: 'Error'),
              Tab(text: 'Timing'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(transaction: transaction),
                _HeadersTab(transaction: transaction),
                _BodyTab(
                  title: 'Request body',
                  preview: transaction.requestBodyPreview,
                  emptyMessage:
                      'Request body capture is disabled by default or the request was skipped because it looked binary/multipart/too large.',
                ),
                _BodyTab(
                  title: 'Response body',
                  preview: transaction.responseBodyPreview,
                  emptyMessage:
                      'Response body capture is disabled by default, or the response has not been captured yet.',
                ),
                _ErrorTab(transaction: transaction),
                _TimingTab(transaction: transaction),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final DebugNetworkTransaction transaction;

  const _DetailHeader({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          bottom: BorderSide(color: Colors.grey[850]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${transaction.method} ${transaction.displayPath}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.statusLabel} · ${transaction.phase.label} · ${transaction.durationLabel}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy full transaction',
            onPressed: () => _copyText(
              context,
              _buildFullCopy(transaction),
              'Transaction copied',
            ),
            icon: const Icon(Icons.copy, size: 18),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final DebugNetworkTransaction transaction;

  const _OverviewTab({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final copyButtons = [
      _ActionButton(
        label: 'Summary',
        icon: Icons.copy,
        onPressed: () => _copyText(
          context,
          _buildSummary(transaction),
          'Summary copied',
        ),
      ),
      _ActionButton(
        label: 'Headers',
        icon: Icons.content_copy,
        onPressed: transaction.requestHeadersPreview == null &&
                transaction.responseHeadersPreview == null
            ? null
            : () => _copyText(
                  context,
                  _buildHeaders(transaction),
                  'Headers copied',
                ),
      ),
      _ActionButton(
        label: 'Request',
        icon: Icons.upload_outlined,
        onPressed: transaction.requestBodyPreview == null
            ? null
            : () => _copyText(
                  context,
                  transaction.requestBodyPreview!,
                  'Request preview copied',
                ),
      ),
      _ActionButton(
        label: 'Response',
        icon: Icons.download_outlined,
        onPressed: transaction.responseBodyPreview == null
            ? null
            : () => _copyText(
                  context,
                  transaction.responseBodyPreview!,
                  'Response preview copied',
                ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: copyButtons),
        const SizedBox(height: 16),
        _InfoCard(
          children: [
            _InfoRow('Method', transaction.method),
            _InfoRow('URL', transaction.url ?? transaction.displayPath),
            _InfoRow('Path', transaction.path),
            if (transaction.query != null)
              _InfoRow('Query', transaction.query!),
            if (transaction.host != null) _InfoRow('Host', transaction.host!),
            _InfoRow('Status', transaction.statusLabel),
            _InfoRow('Phase', transaction.phase.label),
            _InfoRow('Duration', transaction.durationLabel),
            _InfoRow('Started', transaction.startedAt.toString()),
            if (transaction.completedAt != null)
              _InfoRow('Completed', transaction.completedAt.toString()),
            if (transaction.requestId != null)
              _InfoRow('Request ID', transaction.requestId!),
            if (transaction.traceId != null)
              _InfoRow(
                'Trace',
                transaction.traceName == null
                    ? transaction.traceId!
                    : '${transaction.traceName} (${transaction.traceId})',
              ),
            if (transaction.backendRequestId != null)
              _InfoRow('Backend request', transaction.backendRequestId!),
            if (transaction.backendCorrelationId != null)
              _InfoRow(
                'Backend correlation',
                transaction.backendCorrelationId!,
              ),
            if (transaction.backendTraceId != null)
              _InfoRow('Backend trace', transaction.backendTraceId!),
          ],
        ),
        const SizedBox(height: 12),
        if (transaction.metadata.isNotEmpty)
          _InfoCard(
            title: 'Metadata',
            children: [
              for (final entry in transaction.metadata.entries)
                _InfoRow(entry.key, entry.value),
            ],
          ),
      ],
    );
  }
}

class _HeadersTab extends StatelessWidget {
  final DebugNetworkTransaction transaction;

  const _HeadersTab({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PreviewSection(
          title: 'Request headers',
          preview: transaction.requestHeadersPreview,
          emptyMessage: 'No request headers were captured.',
        ),
        const SizedBox(height: 12),
        _PreviewSection(
          title: 'Response headers',
          preview: transaction.responseHeadersPreview,
          emptyMessage: 'No response headers were captured.',
        ),
      ],
    );
  }
}

class _BodyTab extends StatelessWidget {
  final String title;
  final String? preview;
  final String emptyMessage;

  const _BodyTab({
    required this.title,
    required this.preview,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PreviewSection(
          title: title,
          preview: preview,
          emptyMessage: emptyMessage,
        ),
      ],
    );
  }
}

class _ErrorTab extends StatelessWidget {
  final DebugNetworkTransaction transaction;

  const _ErrorTab({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: 'Error',
          children: [
            _InfoRow('Type', transaction.errorType ?? 'n/a'),
            _InfoRow('Message', transaction.errorMessage ?? 'n/a'),
            _InfoRow('Status', transaction.statusLabel),
          ],
        ),
        const SizedBox(height: 12),
        _PreviewSection(
          title: 'Stack trace',
          preview: transaction.stackTrace,
          emptyMessage: 'No stack trace was captured for this transaction.',
        ),
      ],
    );
  }
}

class _TimingTab extends StatelessWidget {
  final DebugNetworkTransaction transaction;

  const _TimingTab({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final duration = transaction.durationMs ?? 0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = screenWidth <= 64 ? 64.0 : screenWidth - 64;
    final barWidth = transaction.durationMs == null
        ? 48.0
        : (maxWidth * (duration / 1000)).clamp(48.0, maxWidth).toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: 'Timing',
          children: [
            _InfoRow('Started', transaction.startedAt.toString()),
            _InfoRow('Duration', transaction.durationLabel),
            _InfoRow('Phase', transaction.phase.label),
            _InfoRow(
              'Waterfall',
              transaction.isPending ? 'Pending' : transaction.durationLabel,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 14,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF222222),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          child: Container(
            width: barWidth,
            height: 14,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: transaction.isPending
                    ? [const Color(0xFFFFC107), const Color(0xFFFFE082)]
                    : [const Color(0xFF4FC3F7), const Color(0xFF7EE0FF)],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _InfoCard({
    this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  final String title;
  final String? preview;
  final String emptyMessage;

  const _PreviewSection({
    required this.title,
    required this.preview,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: title,
      children: [
        if (preview == null)
          Text(
            emptyMessage,
            style: TextStyle(color: Colors.grey[500], height: 1.5),
          )
        else
          SelectableText(
            preview!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.5,
            ),
          ),
      ],
    );
  }
}

String _buildSummary(DebugNetworkTransaction transaction) {
  return [
    '${transaction.method} ${transaction.displayPath}',
    'Status: ${transaction.statusLabel}',
    'Phase: ${transaction.phase.label}',
    'Duration: ${transaction.durationLabel}',
    if (transaction.requestId != null) 'Request ID: ${transaction.requestId}',
    if (transaction.traceId != null)
      'Trace: ${transaction.traceName ?? transaction.traceId}',
    if (transaction.backendCorrelationId != null)
      'Backend correlation: ${transaction.backendCorrelationId}',
  ].join('\n');
}

String _buildHeaders(DebugNetworkTransaction transaction) {
  return [
    if (transaction.requestHeadersPreview != null) ...[
      'Request headers',
      transaction.requestHeadersPreview!,
    ],
    if (transaction.responseHeadersPreview != null) ...[
      'Response headers',
      transaction.responseHeadersPreview!,
    ],
  ].join('\n\n');
}

String _buildFullCopy(DebugNetworkTransaction transaction) {
  return [
    _buildSummary(transaction),
    if (transaction.url != null) 'URL: ${transaction.url}',
    if (transaction.host != null) 'Host: ${transaction.host}',
    if (transaction.query != null) 'Query: ${transaction.query}',
    if (transaction.errorType != null) 'Error type: ${transaction.errorType}',
    if (transaction.errorMessage != null)
      'Error message: ${transaction.errorMessage}',
    if (transaction.stackTrace != null)
      'Stack trace:\n${transaction.stackTrace}',
    if (transaction.requestHeadersPreview != null)
      'Request headers:\n${transaction.requestHeadersPreview}',
    if (transaction.responseHeadersPreview != null)
      'Response headers:\n${transaction.responseHeadersPreview}',
    if (transaction.requestBodyPreview != null)
      'Request body:\n${transaction.requestBodyPreview}',
    if (transaction.responseBodyPreview != null)
      'Response body:\n${transaction.responseBodyPreview}',
    if (transaction.metadata.isNotEmpty)
      'Metadata:\n${transaction.metadata.entries.map((e) => '${e.key}=${e.value}').join('\n')}',
  ].join('\n\n');
}

Future<void> _copyText(
  BuildContext context,
  String text,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
