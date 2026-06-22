part of 'debug_network_inspector_screen.dart';

class _NetworkTimelineOverview extends StatefulWidget {
  final DebugNetworkWaterfallMetrics waterfall;
  final DebugNetworkTimelineViewport viewport;
  final int? selectedLogEntryId;
  final ValueChanged<DebugNetworkTransaction> onSelectRequest;
  final VoidCallback onClearSelection;
  final ValueChanged<DebugNetworkTimelineViewport> onViewportChanged;
  final VoidCallback onResetRange;
  final VoidCallback onToggleCollapsed;

  const _NetworkTimelineOverview({
    super.key,
    required this.waterfall,
    required this.viewport,
    required this.selectedLogEntryId,
    required this.onSelectRequest,
    required this.onClearSelection,
    required this.onViewportChanged,
    required this.onResetRange,
    required this.onToggleCollapsed,
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
              const SizedBox(width: 4),
              Tooltip(
                message: 'Hide timeline',
                child: IconButton(
                  icon: const Icon(
                    Icons.unfold_less_rounded,
                    size: 18,
                    color: _Dk.textSecondary,
                  ),
                  onPressed: widget.onToggleCollapsed,
                  padding: const EdgeInsets.all(6),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
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

class _TimelineCollapsedStrip extends StatelessWidget {
  final VoidCallback onShow;

  const _TimelineCollapsedStrip({
    super.key,
    required this.onShow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _Dk.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Dk.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timeline_outlined,
            size: 14,
            color: _Dk.textSecondary,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Timeline hidden',
              style: TextStyle(
                color: _Dk.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Tooltip(
            message: 'Show timeline',
            child: TextButton(
              onPressed: onShow,
              style: TextButton.styleFrom(
                foregroundColor: _Dk.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Show timeline',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen detail sheet (opened via expand icon)
// ---------------------------------------------------------------------------
