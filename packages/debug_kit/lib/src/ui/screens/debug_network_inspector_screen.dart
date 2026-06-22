import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

part 'debug_network_inspector_detail_sheet.dart';
// ---------------------------------------------------------------------------
// Design tokens — private to this file
// ---------------------------------------------------------------------------
part 'debug_network_inspector_header.dart';
part 'debug_network_inspector_requests.dart';
part 'debug_network_inspector_timeline.dart';

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
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _requestListController = ScrollController();
  final Map<int, GlobalKey> _requestKeys = <int, GlobalKey>{};
  final Map<int, int> _visibleRequestIndexByLogEntryId = <int, int>{};
  DebugNetworkFilterState _filterState = const DebugNetworkFilterState();

  // Only one card expanded at a time to keep the list scannable.
  int? _expandedLogEntryId;
  int? _selectedLogEntryId;
  bool _networkControlsCollapsed = false;
  bool _timelineCollapsed = false;
  bool _searchFocused = false;
  ScrollDirection _lastScrollDirection = ScrollDirection.idle;
  double _scrollDirectionTravel = 0;
  DebugNetworkTimelineViewport _timelineViewport =
      DebugNetworkTimelineViewport.full();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleSearchFocusChanged);
    _searchFocusNode.dispose();
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
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: Column(
              children: [
                _NetworkToolbar(
                  controlsCollapsed: _networkControlsCollapsed,
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  filterState: _filterState,
                  totalCount: allTransactions.length,
                  filteredCount: filtered.length,
                  onFilterChanged: (s) => setState(() => _filterState = s),
                  onClearNetwork: _clearNetwork,
                  onClearFilters: _clearFilters,
                ),
                _SummaryStrip(summary: summary),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _timelineCollapsed
                      ? _TimelineCollapsedStrip(
                          key: const ValueKey('timeline-collapsed'),
                          onShow: _toggleTimelineCollapsed,
                        )
                      : _NetworkTimelineOverview(
                          key: const ValueKey('timeline-expanded'),
                          waterfall: waterfall,
                          viewport: viewport,
                          selectedLogEntryId: _selectedLogEntryId,
                          onSelectRequest: _selectRequest,
                          onClearSelection: _clearTimelineSelection,
                          onViewportChanged: _updateTimelineViewport,
                          onResetRange: _resetTimelineViewport,
                          onToggleCollapsed: _toggleTimelineCollapsed,
                        ),
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
          ),
        );
      },
    );
  }

  void _handleSearchFocusChanged() {
    final focused = _searchFocusNode.hasFocus;
    if (_searchFocused == focused) return;
    setState(() {
      _searchFocused = focused;
      if (focused) {
        _networkControlsCollapsed = false;
      }
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_searchFocused) return false;

    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.idle) {
        _lastScrollDirection = ScrollDirection.idle;
        _scrollDirectionTravel = 0;
      } else if (notification.direction != _lastScrollDirection) {
        _lastScrollDirection = notification.direction;
        _scrollDirectionTravel = 0;
      }
      return false;
    }

    if (notification is! ScrollUpdateNotification) return false;

    final delta = notification.scrollDelta?.abs();
    if (delta == null || delta == 0) return false;

    final direction = _lastScrollDirection;
    if (direction == ScrollDirection.idle) return false;

    _scrollDirectionTravel += delta;
    const threshold = 20.0;

    if (direction == ScrollDirection.reverse &&
        !_networkControlsCollapsed &&
        _scrollDirectionTravel >= threshold) {
      setState(() => _networkControlsCollapsed = true);
      _scrollDirectionTravel = 0;
    } else if (direction == ScrollDirection.forward &&
        _networkControlsCollapsed &&
        _scrollDirectionTravel >= threshold) {
      setState(() => _networkControlsCollapsed = false);
      _scrollDirectionTravel = 0;
    }

    return false;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _filterState = const DebugNetworkFilterState();
      _selectedLogEntryId = null;
      _expandedLogEntryId = null;
      _timelineViewport = DebugNetworkTimelineViewport.full();
      _networkControlsCollapsed = false;
      _scrollDirectionTravel = 0;
      _lastScrollDirection = ScrollDirection.idle;
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

  void _toggleTimelineCollapsed() {
    setState(() => _timelineCollapsed = !_timelineCollapsed);
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
