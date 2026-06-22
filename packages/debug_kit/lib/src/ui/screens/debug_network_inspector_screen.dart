import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/controller/debug_kit_controller.dart';
import '../../core/models/debug_network_filter_state.dart';
import '../../core/models/debug_network_sort_option.dart';
import '../../core/models/debug_network_status_family.dart';
import '../../core/models/debug_network_summary.dart';
import '../../core/models/debug_network_transaction.dart';
import '../../utils/filtering/debug_network_filter.dart';
import '../../utils/network/debug_network_summary_builder.dart';
import '../../utils/network/debug_network_waterfall.dart';

// ---------------------------------------------------------------------------
// Design tokens — private to this file
// ---------------------------------------------------------------------------
abstract final class _Dk {
  static const bg = Color(0xFF0C0C12);
  static const surface = Color(0xFF13131C);
  static const card = Color(0xFF181824);
  static const cardExpanded = Color(0xFF1A1A28);
  static const border = Color(0xFF242436);
  static const borderAccent = Color(0xFF2E2E48);
  static const textPrimary = Color(0xFFE8E8F0);
  static const textSecondary = Color(0xFF8888A8);
  static const textMuted = Color(0xFF555570);
  static const accent = Color(0xFF4D9EFF);
  static const accentDim = Color(0xFF1A3660);
  static const green = Color(0xFF34C77B);
  static const greenDim = Color(0xFF0E2E1E);
  static const amber = Color(0xFFFFB340);
  static const amberDim = Color(0xFF2E2010);
  static const red = Color(0xFFFF4F4F);
  static const redDim = Color(0xFF2E0E0E);
  static const blue = Color(0xFF64B5F6);
  static const purple = Color(0xFFB06EFF);
  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    height: 1.55,
    color: textPrimary,
  );
  static const codeBlock = Color(0xFF0E0E18);
}

// ---------------------------------------------------------------------------
// Method badge color helpers
// ---------------------------------------------------------------------------
Color _methodColor(String method) => switch (method) {
      'GET' => _Dk.accent,
      'POST' => _Dk.green,
      'PUT' || 'PATCH' => _Dk.amber,
      'DELETE' => _Dk.red,
      _ => _Dk.textSecondary,
    };

Color _methodBg(String method) => switch (method) {
      'GET' => _Dk.accentDim,
      'POST' => _Dk.greenDim,
      'PUT' || 'PATCH' => _Dk.amberDim,
      'DELETE' => _Dk.redDim,
      _ => _Dk.surface,
    };

Color _statusColor(DebugNetworkStatusFamily family) => switch (family) {
      DebugNetworkStatusFamily.twoXX => _Dk.green,
      DebugNetworkStatusFamily.threeXX => _Dk.blue,
      DebugNetworkStatusFamily.fourXX => _Dk.amber,
      DebugNetworkStatusFamily.fiveXX => _Dk.red,
      DebugNetworkStatusFamily.unknown => _Dk.textMuted,
    };

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

/// Mobile-first compact network inspector for DebugKit.
///
/// Shows a searchable, filterable, sortable request list.
/// Each card expands inline to reveal tabbed details
/// (Overview / Headers / Request / Response / Error / Timeline).
/// A full-details sheet is available via the expand icon on each card.
class DebugNetworkSummaryScreen extends StatefulWidget {
  const DebugNetworkSummaryScreen({super.key});

  @override
  State<DebugNetworkSummaryScreen> createState() =>
      _DebugNetworkSummaryScreenState();
}

class _DebugNetworkSummaryScreenState extends State<DebugNetworkSummaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _requestListController = ScrollController();
  final Map<int, GlobalKey> _requestKeys = <int, GlobalKey>{};
  final Map<int, int> _visibleRequestIndexByLogEntryId = <int, int>{};
  DebugNetworkFilterState _filterState = const DebugNetworkFilterState();

  // Only one card expanded at a time to keep the list scannable.
  int? _expandedLogEntryId;
  int? _selectedLogEntryId;
  DebugNetworkTimelineViewport _timelineViewport =
      DebugNetworkTimelineViewport.full();

  @override
  void dispose() {
    _searchController.dispose();
    _requestListController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugKitController().store,
      builder: (context, _) {
        final controller = DebugKitController();
        final allTransactions = controller.buildNetworkTransactions();
        final effectiveFilter = _filterState.copyWith(
          slowThresholdMs: controller.config.slowRequestThresholdMs,
        );
        final filtered =
            applyNetworkFiltersAndSort(allTransactions, effectiveFilter);
        final summary = DebugNetworkSummaryBuilder.buildFromTransactions(
          filtered,
          slowRequestThresholdMs: controller.config.slowRequestThresholdMs,
        );
        final waterfall = DebugNetworkWaterfallMetrics.fromTransactions(
          filtered,
          generatedAt: DateTime.now(),
        );
        final viewport = _timelineViewport.normalized();
        _syncVisibleRequests(filtered);

        return SafeArea(
          top: false,
          child: Column(
            children: [
              _NetworkToolbar(
                searchController: _searchController,
                filterState: _filterState,
                totalCount: allTransactions.length,
                filteredCount: filtered.length,
                onFilterChanged: (s) => setState(() => _filterState = s),
                onClearNetwork: _clearNetwork,
                onClearFilters: _clearFilters,
              ),
              _SummaryStrip(summary: summary),
              _NetworkTimelineOverview(
                waterfall: waterfall,
                viewport: viewport,
                selectedLogEntryId: _selectedLogEntryId,
                onSelectRequest: _selectRequest,
                onClearSelection: _clearTimelineSelection,
                onViewportChanged: _updateTimelineViewport,
                onResetRange: _resetTimelineViewport,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(
                        noRequests: allTransactions.isEmpty,
                        onClearFilters: _clearFilters)
                    : _RequestList(
                        transactions: filtered,
                        waterfall: waterfall,
                        viewport: viewport,
                        selectedLogEntryId: _selectedLogEntryId,
                        requestListController: _requestListController,
                        requestKeys: _requestKeys,
                        slowThresholdMs:
                            controller.config.slowRequestThresholdMs,
                        expandedId: _expandedLogEntryId,
                        onExpand: _toggleRequestExpansion,
                        onOpenSheet: (t, w) =>
                            _openSheet(context, t, w, viewport),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _filterState = const DebugNetworkFilterState();
      _selectedLogEntryId = null;
      _expandedLogEntryId = null;
      _timelineViewport = DebugNetworkTimelineViewport.full();
    });
  }

  void _clearTimelineSelection() {
    setState(() {
      _selectedLogEntryId = null;
      _expandedLogEntryId = null;
    });
  }

  void _clearNetwork() {
    DebugKitController().clearNetworkTransactions();
    setState(() {
      _selectedLogEntryId = null;
      _expandedLogEntryId = null;
      _timelineViewport = DebugNetworkTimelineViewport.full();
    });
  }

  void _toggleRequestExpansion(int id) {
    setState(() {
      _selectedLogEntryId = id;
      _expandedLogEntryId = _expandedLogEntryId == id ? null : id;
    });
  }

  void _selectRequest(DebugNetworkTransaction transaction) {
    setState(() {
      _selectedLogEntryId = transaction.logEntryId;
      _expandedLogEntryId = transaction.logEntryId;
    });
    _scrollToRequest(transaction.logEntryId);
  }

  void _updateTimelineViewport(DebugNetworkTimelineViewport viewport) {
    setState(() => _timelineViewport = viewport.normalized());
  }

  void _resetTimelineViewport() {
    setState(() => _timelineViewport = DebugNetworkTimelineViewport.full());
  }

  void _syncVisibleRequests(List<DebugNetworkTransaction> transactions) {
    final visibleIds = transactions.map((tx) => tx.logEntryId).toSet();
    _requestKeys.removeWhere((id, _) => !visibleIds.contains(id));
    _visibleRequestIndexByLogEntryId
      ..clear()
      ..addEntries(
        transactions.asMap().entries.map(
              (entry) => MapEntry(entry.value.logEntryId, entry.key),
            ),
      );

    final selectedVisible =
        _selectedLogEntryId == null || visibleIds.contains(_selectedLogEntryId);
    final expandedVisible =
        _expandedLogEntryId == null || visibleIds.contains(_expandedLogEntryId);
    if (selectedVisible && expandedVisible) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nextSelected = _selectedLogEntryId != null &&
              visibleIds.contains(_selectedLogEntryId)
          ? _selectedLogEntryId
          : null;
      final nextExpanded = _expandedLogEntryId != null &&
              visibleIds.contains(_expandedLogEntryId)
          ? _expandedLogEntryId
          : null;
      if (nextSelected == _selectedLogEntryId &&
          nextExpanded == _expandedLogEntryId) {
        return;
      }
      setState(() {
        _selectedLogEntryId = nextSelected;
        _expandedLogEntryId = nextExpanded;
      });
    });
  }

  void _scrollToRequest(int logEntryId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final key = _requestKeys[logEntryId];
      final context = key?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.12,
        );
        return;
      }

      final index = _visibleRequestIndexByLogEntryId[logEntryId];
      if (index == null || !_requestListController.hasClients) return;

      final estimatedOffset = index * 132.0;
      final maxScrollExtent = _requestListController.position.maxScrollExtent;
      final targetOffset = estimatedOffset.clamp(0.0, maxScrollExtent);
      _requestListController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openSheet(
    BuildContext context,
    DebugNetworkTransaction transaction,
    DebugNetworkWaterfallMetrics? waterfall,
    DebugNetworkTimelineViewport viewport,
  ) async {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: _Dk.surface,
          insetPadding: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
            child: _DetailSheet(
              transaction: transaction,
              waterfall: waterfall,
              viewport: viewport,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: _Dk.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.92,
          child: _DetailSheet(
            transaction: transaction,
            waterfall: waterfall,
            viewport: viewport,
          ),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Toolbar
// ---------------------------------------------------------------------------

class _NetworkToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final DebugNetworkFilterState filterState;
  final int totalCount;
  final int filteredCount;
  final ValueChanged<DebugNetworkFilterState> onFilterChanged;
  final VoidCallback onClearNetwork;
  final VoidCallback onClearFilters;

  const _NetworkToolbar({
    required this.searchController,
    required this.filterState,
    required this.totalCount,
    required this.filteredCount,
    required this.onFilterChanged,
    required this.onClearNetwork,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilters = filterState.hasActiveFilters;
    final showCount = hasFilters && totalCount != filteredCount;

    return Container(
      color: _Dk.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 6),
            child: Row(
              children: [
                Expanded(
                    child: _SearchField(
                  controller: searchController,
                  onChanged: (v) => onFilterChanged(
                    filterState.copyWith(searchQuery: v),
                  ),
                )),
                const SizedBox(width: 2),
                _ToolbarIconButton(
                  icon: Icons.delete_sweep_outlined,
                  tooltip: 'Clear network',
                  onPressed: onClearNetwork,
                ),
                _SortButton(
                  current: filterState.sortOption,
                  onSelected: (v) =>
                      onFilterChanged(filterState.copyWith(sortOption: v)),
                ),
              ],
            ),
          ),
          _FilterChipRow(
            filterState: filterState,
            onChanged: onFilterChanged,
          ),
          if (showCount || hasFilters)
            _FilterBanner(
              shown: filteredCount,
              total: totalCount,
              hasFilters: hasFilters,
              onClear: onClearFilters,
            ),
          Container(height: 1, color: _Dk.border),
        ],
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
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: _Dk.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search requests, status, IDs...',
          hintStyle: const TextStyle(color: _Dk.textMuted, fontSize: 13),
          filled: true,
          fillColor: _Dk.card,
          prefixIcon: const Icon(Icons.search, size: 16, color: _Dk.textMuted),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _Dk.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _Dk.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _Dk.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: _Dk.textSecondary),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _SortButton extends StatelessWidget {
  final DebugNetworkSortOption current;
  final ValueChanged<DebugNetworkSortOption> onSelected;

  const _SortButton({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DebugNetworkSortOption>(
      tooltip: 'Sort',
      initialValue: current,
      onSelected: onSelected,
      color: _Dk.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _Dk.border),
      ),
      itemBuilder: (_) => [
        for (final option in DebugNetworkSortOption.values)
          PopupMenuItem(
            value: option,
            child: Text(
              option.label,
              style: TextStyle(
                color: option == current ? _Dk.accent : _Dk.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.sort_rounded, size: 20, color: _Dk.textSecondary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chips row
// ---------------------------------------------------------------------------

class _FilterChipRow extends StatelessWidget {
  final DebugNetworkFilterState filterState;
  final ValueChanged<DebugNetworkFilterState> onChanged;

  const _FilterChipRow({
    required this.filterState,
    required this.onChanged,
  });

  static const _methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];
  static const _statuses = [
    DebugNetworkStatusFilter.all,
    DebugNetworkStatusFilter.pending,
    DebugNetworkStatusFilter.failed,
    DebugNetworkStatusFilter.twoXX,
    DebugNetworkStatusFilter.threeXX,
    DebugNetworkStatusFilter.fourXX,
    DebugNetworkStatusFilter.fiveXX,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Row(
        children: [
          // Method chips
          for (final method in _methods) ...[
            _Chip(
              label: method,
              color: _methodColor(method),
              selected: filterState.methods.contains(method),
              onTap: () {
                final methods = {...filterState.methods};
                if (methods.contains(method)) {
                  methods.remove(method);
                } else {
                  methods.add(method);
                }
                onChanged(filterState.copyWith(methods: methods));
              },
            ),
            const SizedBox(width: 6),
          ],
          const _ChipDivider(),
          // Status chips
          for (final status in _statuses) ...[
            _Chip(
              label: status.label,
              color: _statusChipColor(status),
              selected: status == DebugNetworkStatusFilter.all
                  ? filterState.statuses.isEmpty
                  : filterState.statuses.contains(status),
              onTap: () {
                if (status == DebugNetworkStatusFilter.all) {
                  onChanged(filterState.copyWith(statuses: const {}));
                  return;
                }
                final statuses = {...filterState.statuses};
                if (statuses.contains(status)) {
                  statuses.remove(status);
                } else {
                  statuses.add(status);
                }
                onChanged(filterState.copyWith(statuses: statuses));
              },
            ),
            const SizedBox(width: 6),
          ],
          const _ChipDivider(),
          _Chip(
            label: 'Slow',
            color: _Dk.amber,
            selected: filterState.slowOnly,
            onTap: () => onChanged(
              filterState.copyWith(slowOnly: !filterState.slowOnly),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusChipColor(DebugNetworkStatusFilter f) => switch (f) {
        DebugNetworkStatusFilter.all => _Dk.accent,
        DebugNetworkStatusFilter.pending => _Dk.amber,
        DebugNetworkStatusFilter.failed => _Dk.red,
        DebugNetworkStatusFilter.twoXX => _Dk.green,
        DebugNetworkStatusFilter.threeXX => _Dk.blue,
        DebugNetworkStatusFilter.fourXX => _Dk.amber,
        DebugNetworkStatusFilter.fiveXX => _Dk.red,
        _ => _Dk.textMuted,
      };
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : _Dk.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.6) : _Dk.border,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : _Dk.textSecondary,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ChipDivider extends StatelessWidget {
  const _ChipDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      color: _Dk.border,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _FilterBanner extends StatelessWidget {
  final int shown;
  final int total;
  final bool hasFilters;
  final VoidCallback onClear;

  const _FilterBanner({
    required this.shown,
    required this.total,
    required this.hasFilters,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: _Dk.accentDim.withValues(alpha: 0.6),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 12, color: _Dk.accent),
          const SizedBox(width: 6),
          Text(
            '$shown / $total requests',
            style: const TextStyle(color: _Dk.accent, fontSize: 11),
          ),
          const Spacer(),
          if (hasFilters)
            GestureDetector(
              onTap: onClear,
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: _Dk.accent,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                  decorationColor: _Dk.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary strip
// ---------------------------------------------------------------------------

class _SummaryStrip extends StatelessWidget {
  final DebugNetworkSummary summary;

  const _SummaryStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Dk.surface,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StripStat(label: 'Total', value: '${summary.totalRequests}'),
            if (summary.failedRequests > 0)
              _StripStat(
                  label: 'Failed',
                  value: '${summary.failedRequests}',
                  color: _Dk.red),
            if (summary.pendingRequests > 0)
              _StripStat(
                  label: 'Pending',
                  value: '${summary.pendingRequests}',
                  color: _Dk.amber),
            if (summary.slowRequests > 0)
              _StripStat(
                  label: 'Slow',
                  value: '${summary.slowRequests}',
                  color: _Dk.amber),
            _StripStat(label: 'Avg', value: '${summary.averageDurationMs}ms'),
          ],
        ),
      ),
    );
  }
}

class _StripStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StripStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _Dk.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color != null ? color!.withValues(alpha: 0.4) : _Dk.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: _Dk.textMuted, fontSize: 10)),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color ?? _Dk.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Request list
// ---------------------------------------------------------------------------

class _RequestList extends StatelessWidget {
  final List<DebugNetworkTransaction> transactions;
  final DebugNetworkWaterfallMetrics waterfall;
  final DebugNetworkTimelineViewport viewport;
  final int? selectedLogEntryId;
  final ScrollController requestListController;
  final Map<int, GlobalKey> requestKeys;
  final int slowThresholdMs;
  final int? expandedId;
  final ValueChanged<int> onExpand;
  final void Function(DebugNetworkTransaction, DebugNetworkWaterfallMetrics)
      onOpenSheet;

  const _RequestList({
    required this.transactions,
    required this.waterfall,
    required this.viewport,
    required this.selectedLogEntryId,
    required this.requestListController,
    required this.requestKeys,
    required this.slowThresholdMs,
    required this.expandedId,
    required this.onExpand,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: requestListController,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final row = waterfall.rowForTransaction(tx);
        final expanded = expandedId == tx.logEntryId;
        final key = requestKeys.putIfAbsent(tx.logEntryId, () => GlobalKey());
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: KeyedSubtree(
            key: key,
            child: _RequestCard(
              transaction: tx,
              waterfall: waterfall,
              row: row,
              viewport: viewport,
              selectedLogEntryId: selectedLogEntryId,
              slowThresholdMs: slowThresholdMs,
              expanded: expanded,
              onTap: () => onExpand(tx.logEntryId),
              onOpenSheet: () => onOpenSheet(tx, waterfall),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Request card — collapsed + expanded with inline tabs
// ---------------------------------------------------------------------------

class _RequestCard extends StatelessWidget {
  final DebugNetworkTransaction transaction;
  final DebugNetworkWaterfallMetrics waterfall;
  final DebugNetworkWaterfallRow? row;
  final DebugNetworkTimelineViewport viewport;
  final int? selectedLogEntryId;
  final int slowThresholdMs;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onOpenSheet;

  const _RequestCard({
    required this.transaction,
    required this.waterfall,
    required this.row,
    required this.viewport,
    required this.selectedLogEntryId,
    required this.slowThresholdMs,
    required this.expanded,
    required this.onTap,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final row = this.row;
    final isSlow = tx.isSlow(slowThresholdMs);
    final isError = tx.isFailed || tx.errorMessage != null;
    final isSelected = selectedLogEntryId == tx.logEntryId;
    final rangeActive = !viewport.isFull;
    final intersectsRange =
        row == null ? true : viewport.intersectsRow(row, waterfall.windowMs);
    final opacity = isSelected
        ? 1.0
        : rangeActive && !intersectsRange
            ? 0.55
            : 1.0;
    final borderColor = isError
        ? _Dk.red.withValues(alpha: 0.35)
        : isSlow
            ? _Dk.amber.withValues(alpha: 0.25)
            : isSelected
                ? _Dk.accent.withValues(alpha: 0.55)
                : expanded
                    ? _Dk.borderAccent
                    : _Dk.border;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: opacity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: expanded ? _Dk.cardExpanded : _Dk.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected
                ? 1.4
                : expanded
                    ? 1.2
                    : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _Dk.accent.withValues(alpha: 0.12),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Collapsed header (always visible) ---
            _CardHeader(
              transaction: tx,
              slowThresholdMs: slowThresholdMs,
              expanded: expanded,
              onTap: onTap,
              onOpenSheet: onOpenSheet,
            ),
            // --- Inline expanded detail ---
            if (expanded)
              _InlineDetail(
                transaction: tx,
                waterfall: waterfall,
                viewport: viewport,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card header row
// ---------------------------------------------------------------------------

class _CardHeader extends StatelessWidget {
  final DebugNetworkTransaction transaction;
  final int slowThresholdMs;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onOpenSheet;

  const _CardHeader({
    required this.transaction,
    required this.slowThresholdMs,
    required this.expanded,
    required this.onTap,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final isSlow = tx.isSlow(slowThresholdMs);
    final isError = tx.isFailed || tx.errorMessage != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Method badge
                _MethodBadge(method: tx.method),
                const SizedBox(width: 9),
                // Path + chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.displayPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _Dk.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _StatusBadge(transaction: tx),
                            const SizedBox(width: 5),
                            if (tx.isPending) ...[
                              const _MiniLabel(
                                  text: 'pending', color: _Dk.amber),
                              const SizedBox(width: 5),
                            ],
                            _MiniLabel(
                              text: tx.durationLabel,
                              color: isSlow ? _Dk.amber : _Dk.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            _MiniLabel(
                              text: tx.phase.label,
                              color: _Dk.textMuted,
                            ),
                            if (tx.requestId != null) ...[
                              const SizedBox(width: 5),
                              _MiniLabel(
                                  text: tx.requestId!,
                                  color: _Dk.textMuted,
                                  mono: true),
                            ],
                            if (tx.backendCorrelationId != null) ...[
                              const SizedBox(width: 5),
                              _MiniLabel(
                                  text: tx.backendCorrelationId!,
                                  color: _Dk.purple,
                                  mono: true),
                            ],
                            if (tx.traceName != null) ...[
                              const SizedBox(width: 5),
                              _MiniLabel(
                                  text: tx.traceName!, color: _Dk.purple),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Right side: time + actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      tx.startedAtLabel,
                      style:
                          const TextStyle(color: _Dk.textMuted, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: onOpenSheet,
                          child: const Tooltip(
                            message: 'Full details',
                            child: Icon(
                              Icons.open_in_full_rounded,
                              size: 14,
                              color: _Dk.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: _Dk.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 7),
            // Error/slow footer inside header
            if (isError || (isSlow && !tx.isPending))
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 2),
                child: Text(
                  isError
                      ? (tx.errorSummary ?? 'Request failed')
                      : 'Slow — ${tx.durationLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isError ? _Dk.red : _Dk.amber,
                    fontSize: 11,
                  ),
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline expanded detail (tabs inside card)
// ---------------------------------------------------------------------------

class _InlineDetail extends StatefulWidget {
  final DebugNetworkTransaction transaction;
  final DebugNetworkWaterfallMetrics waterfall;
  final DebugNetworkTimelineViewport viewport;

  const _InlineDetail({
    required this.transaction,
    required this.waterfall,
    required this.viewport,
  });

  @override
  State<_InlineDetail> createState() => _InlineDetailState();
}

class _InlineDetailState extends State<_InlineDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  List<_TabSpec> get _tabs {
    final tx = widget.transaction;
    return [
      const _TabSpec('Overview'),
      const _TabSpec('Headers'),
      const _TabSpec('Request'),
      const _TabSpec('Response'),
      if (tx.isFailed || tx.errorMessage != null || tx.errorType != null)
        const _TabSpec('Error'),
      const _TabSpec('Timeline'),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 1,
          color: _Dk.border,
          margin: const EdgeInsets.symmetric(horizontal: 10),
        ),
        // Tab bar
        Theme(
          data: Theme.of(context).copyWith(
            tabBarTheme: const TabBarThemeData(
              labelColor: _Dk.accent,
              unselectedLabelColor: _Dk.textMuted,
              indicatorColor: _Dk.accent,
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(fontSize: 11),
              tabAlignment: TabAlignment.start,
            ),
          ),
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: [for (final t in _tabs) Tab(text: t.label)],
          ),
        ),
        Container(height: 1, color: _Dk.border),
        // Tab content — fixed max height, scrollable inside
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: TabBarView(
            controller: _tab,
            children: [
              _OverviewTabContent(transaction: tx),
              _HeadersTabContent(transaction: tx),
              _BodyTabContent(
                preview: tx.requestBodyPreview,
                emptyMessage: _requestBodyEmptyMessage(tx),
              ),
              _BodyTabContent(
                preview: tx.responseBodyPreview,
                emptyMessage: _responseBodyEmptyMessage(tx),
              ),
              if (tx.isFailed ||
                  tx.errorMessage != null ||
                  tx.errorType != null)
                _ErrorTabContent(transaction: tx),
              _TimingTabContent(
                transaction: tx,
                waterfall: widget.waterfall,
                viewport: widget.viewport,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabSpec {
  final String label;
  const _TabSpec(this.label);
}

// ---------------------------------------------------------------------------
// Overview tab content
// ---------------------------------------------------------------------------

class _OverviewTabContent extends StatelessWidget {
  final DebugNetworkTransaction transaction;

  const _OverviewTabContent({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: [
        _KVGrid(rows: [
          _KV('Method', tx.method),
          _KV('Status', tx.statusLabel),
          _KV('Phase', tx.phase.label),
          _KV('Duration', tx.durationLabel),
          if (tx.host != null) _KV('Host', tx.host!),
          _KV('Path', tx.path),
          if (tx.query != null) _KV('Query', tx.query!),
          _KV('Started', tx.startedAtLabel),
          if (tx.completedAtLabel != null)
            _KV('Completed', tx.completedAtLabel!),
        ]),
        if (tx.requestId != null ||
            tx.traceId != null ||
            tx.backendRequestId != null ||
            tx.backendCorrelationId != null ||
            tx.backendTraceId != null) ...[
          const SizedBox(height: 8),
          _KVGrid(rows: [
            if (tx.requestId != null) _KV('Request ID', tx.requestId!),
            if (tx.traceId != null)
              _KV(
                  'Trace',
                  tx.traceName != null
                      ? '${tx.traceName} · ${tx.traceId}'
                      : tx.traceId!),
            if (tx.backendRequestId != null)
              _KV('Backend req', tx.backendRequestId!),
            if (tx.backendCorrelationId != null)
              _KV('Correlation', tx.backendCorrelationId!),
            if (tx.backendTraceId != null)
              _KV('Backend trace', tx.backendTraceId!),
          ]),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            _CopyButton(
              label: 'Summary',
              onPressed: () => _copyText(
                context,
                _buildSummary(tx),
                'Summary copied',
              ),
            ),
            const SizedBox(width: 8),
            if (tx.requestBodyPreview != null || tx.responseBodyPreview != null)
              _CopyButton(
                label: 'Full',
                onPressed: () => _copyText(
                  context,
                  _buildFullCopy(tx),
                  'Transaction copied',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Headers tab content
// ---------------------------------------------------------------------------

class _HeadersTabContent extends StatelessWidget {
  final DebugNetworkTransaction transaction;

  const _HeadersTabContent({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: [
        _PreviewBlock(
          title: 'Request headers',
          preview: tx.requestHeadersPreview,
          emptyMessage: 'No request headers captured.',
        ),
        const SizedBox(height: 10),
        _PreviewBlock(
          title: 'Response headers',
          preview: tx.responseHeadersPreview,
          emptyMessage: 'No response headers captured.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Body tab content (Request / Response)
// ---------------------------------------------------------------------------

class _BodyTabContent extends StatelessWidget {
  final String? preview;
  final String emptyMessage;

  const _BodyTabContent({
    required this.preview,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: [
        _PreviewBlock(
          title: '',
          preview: preview,
          emptyMessage: emptyMessage,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error tab content
// ---------------------------------------------------------------------------

class _ErrorTabContent extends StatelessWidget {
  final DebugNetworkTransaction transaction;

  const _ErrorTabContent({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: [
        _KVGrid(rows: [
          _KV('Type', tx.errorType ?? 'n/a'),
          _KV('Status', tx.statusLabel),
          if (tx.errorMessage != null) _KV('Message', tx.errorMessage!),
        ]),
        if (tx.stackTrace != null) ...[
          const SizedBox(height: 10),
          _PreviewBlock(
            title: 'Stack trace',
            preview: tx.stackTrace,
            emptyMessage: '',
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Timing tab content
// ---------------------------------------------------------------------------

class _TimingTabContent extends StatelessWidget {
  final DebugNetworkTransaction transaction;
  final DebugNetworkWaterfallMetrics? waterfall;
  final DebugNetworkTimelineViewport viewport;

  const _TimingTabContent({
    required this.transaction,
    this.waterfall,
    required this.viewport,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final row = waterfall?.rowForTransaction(tx);
    final selectedRangeLabel =
        waterfall == null ? null : viewport.rangeLabel(waterfall!.windowMs);
    final selectedRangeDurationLabel =
        waterfall == null ? null : viewport.durationLabel(waterfall!.windowMs);
    final intersectsRange = waterfall == null || row == null
        ? true
        : viewport.intersectsRow(row, waterfall!.windowMs);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: [
        _KVGrid(rows: [
          _KV('Started at', tx.startedAtLabel),
          _KV('Completed at', tx.completedAtLabel ?? 'Pending'),
          _KV('Start offset', row?.startOffsetLabel ?? '+0ms'),
          _KV('Duration', row?.durationLabel ?? tx.durationLabel),
          if (waterfall != null) _KV('Visible window', waterfall!.windowLabel),
          if (selectedRangeLabel != null && !viewport.isFull)
            _KV('Selected range', selectedRangeLabel),
          if (selectedRangeDurationLabel != null && !viewport.isFull)
            _KV('Range duration', selectedRangeDurationLabel),
          _KV('In range', intersectsRange ? 'Yes' : 'No'),
          _KV('Phase', tx.phase.label),
          if (tx.traceStep != null) _KV('Trace step', '#${tx.traceStep}'),
          if (tx.requestId != null) _KV('Request ID', tx.requestId!),
        ]),
        const SizedBox(height: 12),
        if (waterfall != null)
          _TimelineDetailBar(
            transaction: tx,
            waterfall: waterfall!,
            viewport: viewport,
          ),
        if (waterfall != null) const SizedBox(height: 12),
        const _TimingNote(),
      ],
    );
  }
}

class _TimingNote extends StatelessWidget {
  const _TimingNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _Dk.accentDim.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Dk.accent.withValues(alpha: 0.25)),
      ),
      child: const Text(
        'DebugKit shows app-level Dio timing. Low-level browser phases such '
        'as DNS, TCP, TLS, and TTFB are not available unless an adapter '
        'provides them.',
        style: TextStyle(color: _Dk.textSecondary, fontSize: 11, height: 1.45),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared timeline overview
// ---------------------------------------------------------------------------

enum _TimelineDragMode { create, move, resizeLeft, resizeRight }

class _TimelineVisualBar {
  final DebugNetworkWaterfallRow row;
  final int laneIndex;
  final Rect rect;
  final Color color;
  final double opacity;
  final bool isSelected;
  final bool isInRange;
  final bool isOverflow;

  const _TimelineVisualBar({
    required this.row,
    required this.laneIndex,
    required this.rect,
    required this.color,
    required this.opacity,
    required this.isSelected,
    required this.isInRange,
    required this.isOverflow,
  });
}

class _TimelineLaneState {
  final int index;
  int lastEndMs = -1;

  _TimelineLaneState(this.index);
}

class _NetworkTimelineOverview extends StatefulWidget {
  final DebugNetworkWaterfallMetrics waterfall;
  final DebugNetworkTimelineViewport viewport;
  final int? selectedLogEntryId;
  final ValueChanged<DebugNetworkTransaction> onSelectRequest;
  final VoidCallback onClearSelection;
  final ValueChanged<DebugNetworkTimelineViewport> onViewportChanged;
  final VoidCallback onResetRange;

  const _NetworkTimelineOverview({
    required this.waterfall,
    required this.viewport,
    required this.selectedLogEntryId,
    required this.onSelectRequest,
    required this.onClearSelection,
    required this.onViewportChanged,
    required this.onResetRange,
  });

  @override
  State<_NetworkTimelineOverview> createState() =>
      _NetworkTimelineOverviewState();
}

class _NetworkTimelineOverviewState extends State<_NetworkTimelineOverview> {
  static const double _minRangeFraction = 0.05;
  static const double _handleTouchWidth = 16;
  static const double _canvasHeight = 88;
  static const double _laneHeight = 6;
  static const double _laneGap = 3;
  static const double _topPadding = 22;
  static const double _barHorizontalPadding = 4;
  static const int _maxVisualLanes = 7;
  _TimelineDragMode? _dragMode;
  double _dragStartFraction = 0;
  DebugNetworkTimelineViewport? _dragStartViewport;

  @override
  Widget build(BuildContext context) {
    final waterfall = widget.waterfall;
    final viewport = widget.viewport.normalized(
      minRangeFraction: _minRangeFraction,
    );
    final selectedRow = widget.selectedLogEntryId == null
        ? null
        : waterfall.rowByLogEntryId(widget.selectedLogEntryId!);
    if (!waterfall.hasMeaningfulTiming || waterfall.rows.length < 2) {
      return Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _Dk.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _Dk.border),
        ),
        child: const Text(
          'Timeline appears after multiple requests.',
          style: TextStyle(color: _Dk.textMuted, fontSize: 11),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: _Dk.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Dk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.selectedLogEntryId != null && selectedRow != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Selected: ${selectedRow.transaction.method} ${selectedRow.transaction.displayPath}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _Dk.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onClearSelection,
                  child: const Text(
                    'Show all',
                    style: TextStyle(
                      color: _Dk.accent,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                      decorationColor: _Dk.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              const Text(
                'Timeline',
                style: TextStyle(
                  color: _Dk.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                viewport.rangeLabel(waterfall.windowMs),
                style: const TextStyle(
                  color: _Dk.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!viewport.isFull)
                GestureDetector(
                  onTap: widget.onResetRange,
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: _Dk.accent,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                      decorationColor: _Dk.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('0ms',
                  style: TextStyle(color: _Dk.textMuted, fontSize: 10)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(height: 1, color: _Dk.borderAccent),
              ),
              Text('${(waterfall.windowMs / 2).round()}ms',
                  style: const TextStyle(color: _Dk.textMuted, fontSize: 10)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(height: 1, color: _Dk.borderAccent),
              ),
              const SizedBox(width: 8),
              Text(waterfall.windowLabel,
                  style: const TextStyle(color: _Dk.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, _canvasHeight);
              final slowThresholdMs =
                  DebugKitController().config.slowRequestThresholdMs;
              final visualBars = _packTimelineVisualBars(
                waterfall: waterfall,
                viewport: viewport,
                selectedLogEntryId: widget.selectedLogEntryId,
                size: size,
                slowThresholdMs: slowThresholdMs,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final local = details.localPosition;
                  final bar = _hitTestVisualBar(
                    localPosition: local,
                    bars: visualBars,
                  );
                  if (bar != null) {
                    if (bar.row.transaction.logEntryId ==
                        widget.selectedLogEntryId) {
                      widget.onClearSelection();
                    } else {
                      widget.onSelectRequest(bar.row.transaction);
                    }
                  } else if (widget.selectedLogEntryId != null) {
                    widget.onClearSelection();
                  }
                },
                onPanStart: (details) {
                  final local = details.localPosition;
                  final fraction = _fractionFromDx(local.dx, size.width);
                  final mode = _resolveDragMode(fraction, viewport);
                  setState(() {
                    _dragMode = mode;
                    _dragStartFraction = fraction;
                    _dragStartViewport = viewport;
                  });
                },
                onPanUpdate: (details) {
                  final mode = _dragMode;
                  final startViewport = _dragStartViewport ?? viewport;
                  if (mode == null) return;
                  final fraction = _fractionFromDx(
                    details.localPosition.dx,
                    size.width,
                  );
                  final next = _applyDrag(
                    mode: mode,
                    currentFraction: fraction,
                    startFraction: _dragStartFraction,
                    startViewport: startViewport,
                  );
                  widget.onViewportChanged(next);
                },
                onPanEnd: (_) {
                  setState(() {
                    _dragMode = null;
                    _dragStartViewport = null;
                  });
                },
                child: CustomPaint(
                  size: size,
                  painter: _NetworkTimelineOverviewPainter(
                    waterfall: waterfall,
                    viewport: viewport,
                    selectedLogEntryId: widget.selectedLogEntryId,
                    visualBars: visualBars,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                viewport.rangeLabel(waterfall.windowMs),
                style: const TextStyle(
                  color: _Dk.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                viewport.durationLabel(waterfall.windowMs),
                style: const TextStyle(
                  color: _Dk.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _TimelineDragMode _resolveDragMode(
    double fraction,
    DebugNetworkTimelineViewport viewport,
  ) {
    if (viewport.isFull) return _TimelineDragMode.create;
    final start = viewport.rangeStartFraction;
    final end = viewport.rangeEndFraction;
    const handle = _handleTouchWidth / 100;
    if ((fraction - start).abs() <= handle) return _TimelineDragMode.resizeLeft;
    if ((fraction - end).abs() <= handle) return _TimelineDragMode.resizeRight;
    if (fraction >= start && fraction <= end) return _TimelineDragMode.move;
    return _TimelineDragMode.create;
  }

  DebugNetworkTimelineViewport _applyDrag({
    required _TimelineDragMode mode,
    required double currentFraction,
    required double startFraction,
    required DebugNetworkTimelineViewport startViewport,
  }) {
    final clampedCurrent = currentFraction.clamp(0.0, 1.0).toDouble();
    switch (mode) {
      case _TimelineDragMode.create:
        final start = math.min(startFraction, clampedCurrent);
        final end = math.max(startFraction, clampedCurrent);
        return DebugNetworkTimelineViewport(
          rangeStartFraction: start,
          rangeEndFraction: math.max(end, start + _minRangeFraction),
          selectedLogEntryId: startViewport.selectedLogEntryId,
        ).normalized(minRangeFraction: _minRangeFraction);
      case _TimelineDragMode.move:
        return startViewport.moveByFraction(
          clampedCurrent - startFraction,
          minRangeFraction: _minRangeFraction,
        );
      case _TimelineDragMode.resizeLeft:
        return startViewport.resizeLeftToFraction(
          clampedCurrent,
          minRangeFraction: _minRangeFraction,
        );
      case _TimelineDragMode.resizeRight:
        return startViewport.resizeRightToFraction(
          clampedCurrent,
          minRangeFraction: _minRangeFraction,
        );
    }
  }

  double _fractionFromDx(double dx, double width) {
    if (width <= 0) return 0;
    return (dx / width).clamp(0.0, 1.0).toDouble();
  }

  List<_TimelineVisualBar> _packTimelineVisualBars({
    required DebugNetworkWaterfallMetrics waterfall,
    required DebugNetworkTimelineViewport viewport,
    required int? selectedLogEntryId,
    required Size size,
    required int slowThresholdMs,
  }) {
    final rows = waterfall.rows.toList()
      ..sort((a, b) {
        final compare = a.startOffsetMs.compareTo(b.startOffsetMs);
        if (compare != 0) return compare;
        return b.durationMs.compareTo(a.durationMs);
      });
    if (rows.isEmpty) return const <_TimelineVisualBar>[];

    final lanes = List<_TimelineLaneState>.generate(
      _maxVisualLanes,
      _TimelineLaneState.new,
      growable: false,
    );
    final bars = <_TimelineVisualBar>[];
    final availableWidth =
        math.max(0.0, size.width - (_barHorizontalPadding * 2));
    const laneStride = _laneHeight + _laneGap;
    final selectedActive = selectedLogEntryId != null;
    final rangeActive = !viewport.isFull;

    for (final row in rows) {
      final availableLane = lanes.firstWhere(
        (lane) => lane.lastEndMs <= row.startOffsetMs,
        orElse: () => lanes.reduce(
          (best, lane) => lane.lastEndMs <= best.lastEndMs ? lane : best,
        ),
      );
      final overflow = availableLane.lastEndMs > row.startOffsetMs;
      final left = _barHorizontalPadding +
          (row.barStartFraction * availableWidth).clamp(0.0, availableWidth);
      final width = math.max(
        3.0,
        row.renderBarWidthFraction(0.02) * availableWidth,
      );
      final rightBound =
          math.max(0.0, availableWidth - (left - _barHorizontalPadding));
      final rect = Rect.fromLTWH(
        left,
        _topPadding + availableLane.index * laneStride,
        math.min(width, rightBound),
        _laneHeight,
      );

      final isSelected = selectedLogEntryId == row.transaction.logEntryId;
      final isInRange =
          !rangeActive || viewport.intersectsRow(row, waterfall.windowMs);
      final baseColor = row.transaction.isFailed
          ? _Dk.red
          : row.isPending
              ? _Dk.amber
              : row.transaction.isSlow(slowThresholdMs)
                  ? _Dk.amber
                  : _Dk.green;
      var opacity = 0.92;
      if (selectedActive && !isSelected) {
        opacity *= 0.36;
      }
      if (rangeActive && !isInRange && !isSelected) {
        opacity *= 0.62;
      }
      if (overflow) {
        opacity *= 0.82;
      }

      bars.add(
        _TimelineVisualBar(
          row: row,
          laneIndex: availableLane.index,
          rect: rect,
          color: baseColor,
          opacity: opacity,
          isSelected: isSelected,
          isInRange: isInRange,
          isOverflow: overflow,
        ),
      );
      availableLane.lastEndMs = row.endOffsetMs;
    }

    return bars;
  }

  _TimelineVisualBar? _hitTestVisualBar({
    required Offset localPosition,
    required List<_TimelineVisualBar> bars,
  }) {
    if (bars.isEmpty) return null;

    final directHits = bars
        .where((bar) => bar.rect.inflate(4).contains(localPosition))
        .toList(growable: false);
    if (directHits.isNotEmpty) {
      directHits.sort((a, b) {
        if (a.isSelected != b.isSelected) {
          return a.isSelected ? -1 : 1;
        }
        final aContains = a.rect.contains(localPosition);
        final bContains = b.rect.contains(localPosition);
        if (aContains != bContains) return aContains ? -1 : 1;
        return a.laneIndex.compareTo(b.laneIndex);
      });
      return directHits.first;
    }
    return null;
  }
}

class _NetworkTimelineOverviewPainter extends CustomPainter {
  final DebugNetworkWaterfallMetrics waterfall;
  final DebugNetworkTimelineViewport viewport;
  final int? selectedLogEntryId;
  final List<_TimelineVisualBar> visualBars;

  const _NetworkTimelineOverviewPainter({
    required this.waterfall,
    required this.viewport,
    required this.selectedLogEntryId,
    required this.visualBars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = _Dk.bg;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ),
      background,
    );

    _paintGrid(canvas, size);
    _paintRangeOverlay(canvas, size);
    _paintBars(canvas);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = _Dk.border.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (final x in <double>[0, size.width / 2, size.width]) {
      canvas.drawLine(
        Offset(x, _NetworkTimelineOverviewState._topPadding - 2),
        Offset(x, size.height - 10),
        gridPaint,
      );
    }
    canvas.drawLine(
      Offset(0, size.height - 12),
      Offset(size.width, size.height - 12),
      gridPaint,
    );
  }

  void _paintRangeOverlay(Canvas canvas, Size size) {
    if (viewport.isFull) return;

    final rangeStart = viewport.rangeStartFraction * size.width;
    final rangeEnd = viewport.rangeEndFraction * size.width;
    final rangeRect = Rect.fromLTRB(
      rangeStart,
      12,
      rangeEnd,
      size.height - 12,
    );
    final rangePaint = Paint()
      ..color = _Dk.accent.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rangeRect, const Radius.circular(10)),
      rangePaint,
    );

    final borderPaint = Paint()
      ..color = _Dk.accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rangeRect, const Radius.circular(10)),
      borderPaint,
    );

    final handlePaint = Paint()..color = _Dk.accent;
    const handleWidth = 5.0;
    const handleRadius = 4.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rangeStart, size.height / 2),
          width: handleWidth,
          height: 34,
        ),
        const Radius.circular(4),
      ),
      handlePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rangeEnd, size.height / 2),
          width: handleWidth,
          height: 34,
        ),
        const Radius.circular(4),
      ),
      handlePaint,
    );
    canvas.drawCircle(
      Offset(rangeStart, size.height / 2),
      handleRadius,
      handlePaint,
    );
    canvas.drawCircle(
      Offset(rangeEnd, size.height / 2),
      handleRadius,
      handlePaint,
    );
  }

  void _paintBars(Canvas canvas) {
    for (final bar in visualBars) {
      final fillPaint = Paint()
        ..color = bar.color.withValues(alpha: bar.opacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar.rect, const Radius.circular(5)),
        fillPaint,
      );

      if (bar.row.isPending || bar.row.isEstimated) {
        _paintStripes(
            canvas, bar.rect, fillPaint.color.withValues(alpha: 0.26));
      }

      if (bar.isSelected) {
        final outlinePaint = Paint()
          ..color = _Dk.accent.withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              bar.rect.inflate(1.5), const Radius.circular(5)),
          outlinePaint,
        );
      } else if (bar.isInRange && !viewport.isFull) {
        final rangePaint = Paint()
          ..color = _Dk.borderAccent.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              bar.rect.inflate(0.6), const Radius.circular(5)),
          rangePaint,
        );
      }
    }
  }

  void _paintStripes(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const spacing = 7.0;
    for (var x = rect.left - rect.height; x < rect.right; x += spacing) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkTimelineOverviewPainter oldDelegate) {
    return oldDelegate.waterfall != waterfall ||
        oldDelegate.viewport != viewport ||
        oldDelegate.selectedLogEntryId != selectedLogEntryId ||
        oldDelegate.visualBars != visualBars;
  }
}

class _TimelineDetailBar extends StatelessWidget {
  final DebugNetworkTransaction transaction;
  final DebugNetworkWaterfallMetrics waterfall;
  final DebugNetworkTimelineViewport viewport;

  const _TimelineDetailBar({
    required this.transaction,
    required this.waterfall,
    required this.viewport,
  });

  @override
  Widget build(BuildContext context) {
    final row = waterfall.rowForTransaction(transaction);
    final selectedRangeLabel =
        viewport.isFull ? null : viewport.rangeLabel(waterfall.windowMs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              row?.timingLabel ?? transaction.durationLabel,
              style: const TextStyle(color: _Dk.textMuted, fontSize: 11),
            ),
            const Spacer(),
            if (selectedRangeLabel != null)
              Text(
                selectedRangeLabel,
                style: const TextStyle(color: _Dk.textMuted, fontSize: 11),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 46,
          child: CustomPaint(
            painter: _TimelineDetailBarPainter(
              waterfall: waterfall,
              viewport: viewport,
              transaction: transaction,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineDetailBarPainter extends CustomPainter {
  final DebugNetworkWaterfallMetrics waterfall;
  final DebugNetworkTimelineViewport viewport;
  final DebugNetworkTransaction transaction;

  const _TimelineDetailBarPainter({
    required this.waterfall,
    required this.viewport,
    required this.transaction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = _Dk.border.withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 6, size.width, 22),
        const Radius.circular(99),
      ),
      bg,
    );

    final row = waterfall.rowForTransaction(transaction);
    if (row == null) return;

    final left = row.barStartFraction * size.width;
    final width = math.max(6.0, row.renderBarWidthFraction(0.04) * size.width);
    final rect = Rect.fromLTWH(left, 6, width, 22);
    final color = row.transaction.isFailed
        ? _Dk.red
        : row.isPending
            ? _Dk.amber
            : row.transaction
                    .isSlow(DebugKitController().config.slowRequestThresholdMs)
                ? _Dk.amber
                : _Dk.accent;

    final fill = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(99)),
      fill,
    );

    if (row.isPending || row.isEstimated) {
      final stripePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..strokeWidth = 1;
      const spacing = 7.0;
      for (var x = rect.left - rect.height; x < rect.right; x += spacing) {
        canvas.drawLine(
          Offset(x, rect.bottom),
          Offset(x + rect.height, rect.top),
          stripePaint,
        );
      }
    }

    if (!viewport.isFull) {
      final rangeLeft = viewport.rangeStartFraction * size.width;
      final rangeRight = viewport.rangeEndFraction * size.width;
      final rangePaint = Paint()
        ..color = _Dk.accent.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(rangeLeft, 3, rangeRight, 31),
          const Radius.circular(99),
        ),
        rangePaint,
      );
    }

    final outlinePaint = Paint()
      ..color = _Dk.accent.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(99)),
      outlinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineDetailBarPainter oldDelegate) {
    return oldDelegate.waterfall != waterfall ||
        oldDelegate.viewport != viewport ||
        oldDelegate.transaction != transaction;
  }
}

// ---------------------------------------------------------------------------
// Full-screen detail sheet (opened via expand icon)
// ---------------------------------------------------------------------------

class _DetailSheet extends StatelessWidget {
  final DebugNetworkTransaction transaction;
  final DebugNetworkWaterfallMetrics? waterfall;
  final DebugNetworkTimelineViewport viewport;

  const _DetailSheet({
    required this.transaction,
    this.waterfall,
    required this.viewport,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final hasError =
        tx.isFailed || tx.errorMessage != null || tx.errorType != null;
    final tabCount = 5 + (hasError ? 1 : 0);

    return DefaultTabController(
      length: tabCount,
      child: Column(
        children: [
          // Sheet header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            decoration: const BoxDecoration(
              color: _Dk.surface,
              border: Border(bottom: BorderSide(color: _Dk.border)),
            ),
            child: Row(
              children: [
                _MethodBadge(method: tx.method),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.displayPath,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _Dk.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _StatusBadge(transaction: tx),
                          const SizedBox(width: 6),
                          Text(
                            '${tx.phase.label} · ${tx.durationLabel}',
                            style: const TextStyle(
                                color: _Dk.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy transaction',
                  icon: const Icon(Icons.copy_rounded,
                      size: 18, color: _Dk.textSecondary),
                  onPressed: () => _copyText(
                      context, _buildFullCopy(tx), 'Transaction copied'),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: _Dk.textSecondary),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          // Tab bar
          Theme(
            data: Theme.of(context).copyWith(
              tabBarTheme: const TabBarThemeData(
                labelColor: _Dk.accent,
                unselectedLabelColor: _Dk.textMuted,
                indicatorColor: _Dk.accent,
                labelStyle:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: TextStyle(fontSize: 12),
                tabAlignment: TabAlignment.start,
              ),
            ),
            child: TabBar(
              isScrollable: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: _Dk.border,
              tabs: [
                const Tab(text: 'Overview'),
                const Tab(text: 'Headers'),
                const Tab(text: 'Request'),
                const Tab(text: 'Response'),
                if (hasError) const Tab(text: 'Error'),
                const Tab(text: 'Timeline'),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: _Dk.bg,
              child: TabBarView(
                children: [
                  _OverviewTabContent(transaction: tx),
                  _HeadersTabContent(transaction: tx),
                  _BodyTabContent(
                    preview: tx.requestBodyPreview,
                    emptyMessage: _requestBodyEmptyMessage(tx),
                  ),
                  _BodyTabContent(
                    preview: tx.responseBodyPreview,
                    emptyMessage: _responseBodyEmptyMessage(tx),
                  ),
                  if (hasError) _ErrorTabContent(transaction: tx),
                  _TimingTabContent(
                    transaction: tx,
                    waterfall: waterfall,
                    viewport: viewport,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _MethodBadge extends StatelessWidget {
  final String method;

  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final color = _methodColor(method);
    final bg = _methodBg(method);
    // Shorten PATCH/DELETE to fit compact width
    final label = method.length > 4 ? method.substring(0, 4) : method;
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
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
    final tx = transaction;
    final color = tx.isPending ? _Dk.amber : _statusColor(tx.statusFamily);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        tx.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final String text;
  final Color color;
  final bool mono;

  const _MiniLabel({
    required this.text,
    required this.color,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontFamily: mono ? 'monospace' : null,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// Key-value grid — two-column compact display
class _KV {
  final String key;
  final String value;
  const _KV(this.key, this.value);
}

class _KVGrid extends StatelessWidget {
  final List<_KV> rows;

  const _KVGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _Dk.codeBlock,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _Dk.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _KVRow(kv: rows[i]),
            if (i < rows.length - 1)
              Container(
                  height: 1,
                  color: _Dk.border,
                  margin: const EdgeInsets.symmetric(vertical: 4)),
          ],
        ],
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  final _KV kv;

  const _KVRow({required this.kv});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            kv.key,
            style: const TextStyle(color: _Dk.textMuted, fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            kv.value,
            style: const TextStyle(
              color: _Dk.textPrimary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// Preview block — code-style box with optional copy button
class _PreviewBlock extends StatelessWidget {
  final String title;
  final String? preview;
  final String emptyMessage;

  const _PreviewBlock({
    required this.title,
    required this.preview,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty) ...[
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: _Dk.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (preview != null)
                _CopyButton(
                  label: 'Copy',
                  onPressed: () => _copyText(context, preview!, 'Copied'),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: _Dk.codeBlock,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _Dk.border),
          ),
          child: preview == null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(
                        color: _Dk.textMuted, fontSize: 11, height: 1.6),
                  ),
                )
              : Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: SelectableText(
                      preview!,
                      style: _Dk.mono,
                    ),
                  ),
                ),
        ),
        if (title.isEmpty && preview != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _CopyButton(
                label: 'Copy',
                onPressed: () => _copyText(context, preview!, 'Copied'),
              ),
            ),
          ),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _CopyButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _Dk.accentDim,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _Dk.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.copy_rounded, size: 11, color: _Dk.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                  color: _Dk.accent, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final bool noRequests;
  final VoidCallback onClearFilters;

  const _EmptyState({
    required this.noRequests,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.network_check_outlined,
                size: 56, color: _Dk.textMuted),
            const SizedBox(height: 16),
            Text(
              noRequests ? 'No network requests yet' : 'No matching requests',
              style: const TextStyle(
                color: _Dk.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noRequests
                  ? 'Add debug_kit_dio to your Dio instance to capture requests automatically.'
                  : 'Try adjusting the search or filter chips.',
              style: const TextStyle(
                  color: _Dk.textSecondary, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (!noRequests) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off, size: 15),
                label: const Text('Clear filters'),
                style: TextButton.styleFrom(foregroundColor: _Dk.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty-state message helpers — context-aware, not hardcoded "disabled"
// ---------------------------------------------------------------------------

/// Returns an accurate empty-state message for the Request body tab.
/// The message reflects why the preview is absent — no body on this request
/// type, body was too large, or capture is genuinely disabled.
String _requestBodyEmptyMessage(DebugNetworkTransaction tx) {
  // GET / HEAD / DELETE typically have no body
  if (tx.method == 'GET' || tx.method == 'HEAD' || tx.method == 'DELETE') {
    return '${tx.method} requests do not carry a request body.';
  }
  // Pending requests haven't finished — body may come later
  if (tx.isPending) {
    return 'Request is still pending.';
  }
  // Skipped reasons may appear in metadata
  final skip = tx.metadata['requestBodySkipReason'] ??
      tx.metadata['request_body_skip_reason'];
  if (skip != null) return 'Body not captured: $skip';
  // Default: probably disabled or empty
  return 'No request body captured.\n'
      'If you expected a body here, ensure captureRequestBody: true is set in DebugKitDioConfig.';
}

/// Returns an accurate empty-state message for the Response body tab.
String _responseBodyEmptyMessage(DebugNetworkTransaction tx) {
  if (tx.isPending) {
    return 'Response not received yet — request is still pending.';
  }
  if (tx.isFailed && tx.statusCode == null) {
    return 'Request failed before a response was received.';
  }
  final skip = tx.metadata['responseBodySkipReason'] ??
      tx.metadata['response_body_skip_reason'];
  if (skip != null) return 'Body not captured: $skip';
  return 'No response body captured.\n'
      'If you expected a body here, ensure captureResponseBody: true is set in DebugKitDioConfig.';
}

// ---------------------------------------------------------------------------
// Copy helpers and text builders
// ---------------------------------------------------------------------------

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
        backgroundColor: _Dk.card,
      ),
    );
  }
}

String _buildSummary(DebugNetworkTransaction tx) {
  return [
    '${tx.method} ${tx.displayPath}',
    'Status: ${tx.statusLabel}',
    'Phase: ${tx.phase.label}',
    'Duration: ${tx.durationLabel}',
    if (tx.requestId != null) 'Request ID: ${tx.requestId}',
    if (tx.traceId != null) 'Trace: ${tx.traceName ?? tx.traceId}',
    if (tx.backendCorrelationId != null)
      'Correlation: ${tx.backendCorrelationId}',
  ].join('\n');
}

String _buildFullCopy(DebugNetworkTransaction tx) {
  return [
    _buildSummary(tx),
    if (tx.url != null) 'URL: ${tx.url}',
    if (tx.host != null) 'Host: ${tx.host}',
    if (tx.query != null) 'Query: ${tx.query}',
    if (tx.errorType != null) 'Error type: ${tx.errorType}',
    if (tx.errorMessage != null) 'Error: ${tx.errorMessage}',
    if (tx.stackTrace != null) 'Stack:\n${tx.stackTrace}',
    if (tx.requestHeadersPreview != null)
      'Request headers:\n${tx.requestHeadersPreview}',
    if (tx.responseHeadersPreview != null)
      'Response headers:\n${tx.responseHeadersPreview}',
    if (tx.requestBodyPreview != null)
      'Request body:\n${tx.requestBodyPreview}',
    if (tx.responseBodyPreview != null)
      'Response body:\n${tx.responseBodyPreview}',
    if (tx.metadata.isNotEmpty)
      'Metadata:\n${tx.metadata.entries.map((e) => '${e.key}=${e.value}').join('\n')}',
  ].join('\n\n');
}
