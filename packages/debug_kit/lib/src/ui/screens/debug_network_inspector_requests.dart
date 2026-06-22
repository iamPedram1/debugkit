part of 'debug_network_inspector_screen.dart';

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
