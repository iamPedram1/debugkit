part of 'debug_network_inspector_screen.dart';

class _NetworkToolbar extends StatelessWidget {
  final bool controlsCollapsed;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final DebugNetworkFilterState filterState;
  final int totalCount;
  final int filteredCount;
  final ValueChanged<DebugNetworkFilterState> onFilterChanged;
  final VoidCallback onClearNetwork;
  final VoidCallback onClearFilters;

  const _NetworkToolbar({
    required this.controlsCollapsed,
    required this.searchController,
    required this.searchFocusNode,
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
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controlsCollapsed)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasFilters
                            ? '$filteredCount / $totalCount requests'
                            : '$totalCount requests',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _Dk.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showCount)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Text(
                          'Filtered',
                          style: TextStyle(
                            color: _Dk.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onChanged: (v) => onFilterChanged(
                          filterState.copyWith(searchQuery: v),
                        ),
                      ),
                    ),
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
            ],
            Container(height: 1, color: _Dk.border),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
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
