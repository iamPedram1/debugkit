import '../../core/models/debug_network_transaction.dart';

/// Timing geometry for the lightweight network timeline visualization.
class DebugNetworkWaterfallMetrics {
  final DateTime windowStart;
  final DateTime windowEnd;
  final int windowMs;
  final DateTime generatedAt;
  final List<DebugNetworkWaterfallRow> rows;

  const DebugNetworkWaterfallMetrics({
    required this.windowStart,
    required this.windowEnd,
    required this.windowMs,
    required this.generatedAt,
    required this.rows,
  });

  static DebugNetworkWaterfallMetrics fromTransactions(
    List<DebugNetworkTransaction> transactions, {
    DateTime? generatedAt,
    double minBarFraction = 0.06,
  }) {
    final now = generatedAt ?? DateTime.now();
    if (transactions.isEmpty) {
      return DebugNetworkWaterfallMetrics(
        windowStart: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        windowEnd: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        windowMs: 1,
        generatedAt: now,
        rows: [],
      );
    }

    final windowStart = _earliestStart(transactions);
    final windowEnd =
        _latestEnd(transactions, generatedAt: now, windowStart: windowStart);
    final windowMs =
        _clampWindowMs(windowEnd.difference(windowStart).inMilliseconds);

    final rows = transactions.map((transaction) {
      final end = _effectiveEnd(transaction,
          generatedAt: now, windowStart: windowStart);
      final startOffsetMs = _clampOffsetMs(
          transaction.startedAt.difference(windowStart).inMilliseconds);
      final endOffsetMs =
          _clampOffsetMs(end.difference(windowStart).inMilliseconds);
      final durationMs = _clampDurationMs(endOffsetMs - startOffsetMs);
      final barStartFraction =
          _clampFraction(startOffsetMs / windowMs.toDouble());
      var barWidthFraction = _clampFraction(durationMs / windowMs.toDouble());
      if (barStartFraction + barWidthFraction > 1) {
        barWidthFraction = (1 - barStartFraction).clamp(0.0, 1.0).toDouble();
      }

      final isPending = transaction.isPending;
      final isEstimated = isPending || _needsEstimatedTiming(transaction);

      return DebugNetworkWaterfallRow(
        transaction: transaction,
        startOffsetMs: startOffsetMs,
        endOffsetMs: endOffsetMs,
        durationMs: durationMs,
        barStartFraction: barStartFraction,
        barWidthFraction: barWidthFraction,
        isPending: isPending,
        isEstimated: isEstimated,
      );
    }).toList(growable: false);

    return DebugNetworkWaterfallMetrics(
      windowStart: windowStart,
      windowEnd: windowEnd,
      windowMs: windowMs,
      generatedAt: now,
      rows: rows,
    );
  }

  DebugNetworkWaterfallRow? rowByLogEntryId(int id) {
    for (final row in rows) {
      if (row.transaction.logEntryId == id) return row;
    }
    return null;
  }

  DebugNetworkWaterfallRow? rowForTransaction(DebugNetworkTransaction tx) {
    final byLogEntryId = rowByLogEntryId(tx.logEntryId);
    if (byLogEntryId != null) return byLogEntryId;

    final requestId = tx.requestId;
    if (requestId != null) {
      for (final row in rows) {
        if (row.transaction.requestId == requestId) return row;
      }
    }

    return null;
  }

  bool get hasMeaningfulTiming {
    if (rows.length >= 2) return true;
    return rows.any((row) => row.isPending || row.durationMs > 0);
  }

  String get windowLabel => '${windowMs}ms';

  static DateTime _earliestStart(List<DebugNetworkTransaction> transactions) {
    var earliest = transactions.first.startedAt;
    for (final transaction in transactions.skip(1)) {
      if (transaction.startedAt.isBefore(earliest)) {
        earliest = transaction.startedAt;
      }
    }
    return earliest;
  }

  static DateTime _latestEnd(
    List<DebugNetworkTransaction> transactions, {
    required DateTime generatedAt,
    required DateTime windowStart,
  }) {
    var latest = windowStart;
    for (final transaction in transactions) {
      final end = _effectiveEnd(
        transaction,
        generatedAt: generatedAt,
        windowStart: windowStart,
      );
      if (end.isAfter(latest)) {
        latest = end;
      }
    }
    return latest;
  }

  static DateTime _effectiveEnd(
    DebugNetworkTransaction transaction, {
    required DateTime generatedAt,
    required DateTime windowStart,
  }) {
    if (transaction.isPending) {
      return generatedAt.isBefore(transaction.startedAt)
          ? transaction.startedAt
          : generatedAt;
    }

    final explicitCompletedAt = transaction.completedAt;
    if (explicitCompletedAt != null) {
      return explicitCompletedAt.isBefore(transaction.startedAt)
          ? transaction.startedAt
          : explicitCompletedAt;
    }

    final durationMs = transaction.durationMs;
    if (durationMs != null && durationMs > 0) {
      final end = transaction.startedAt.add(Duration(milliseconds: durationMs));
      return end.isBefore(transaction.startedAt) ? transaction.startedAt : end;
    }

    if (_needsEstimatedTiming(transaction)) {
      return transaction.startedAt;
    }

    return transaction.startedAt.isBefore(windowStart)
        ? windowStart
        : transaction.startedAt;
  }

  static bool _needsEstimatedTiming(DebugNetworkTransaction transaction) {
    return !transaction.isPending &&
        transaction.durationMs == null &&
        transaction.completedAt == null;
  }

  static int _clampWindowMs(int windowMs) {
    if (windowMs <= 0) return 1;
    return windowMs;
  }

  static int _clampOffsetMs(int value) {
    if (value < 0) return 0;
    return value;
  }

  static int _clampDurationMs(int value) {
    if (value < 0) return 0;
    return value;
  }

  static double _clampFraction(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}

/// Per-row waterfall geometry.
class DebugNetworkWaterfallRow {
  final DebugNetworkTransaction transaction;
  final int startOffsetMs;
  final int endOffsetMs;
  final int durationMs;
  final double barStartFraction;
  final double barWidthFraction;
  final bool isPending;
  final bool isEstimated;

  const DebugNetworkWaterfallRow({
    required this.transaction,
    required this.startOffsetMs,
    required this.endOffsetMs,
    required this.durationMs,
    required this.barStartFraction,
    required this.barWidthFraction,
    required this.isPending,
    required this.isEstimated,
  });

  String get startOffsetLabel => _formatOffset(startOffsetMs);

  String get durationLabel {
    if (isPending) return '${durationMs}ms';
    if (isEstimated && durationMs == 0) return 'unknown';
    return '${durationMs}ms';
  }

  String get timingLabel {
    if (isPending) {
      return '$startOffsetLabel · pending';
    }
    return '$startOffsetLabel · $durationLabel';
  }

  double renderBarWidthFraction(double minBarFraction) {
    final visibleFraction =
        barWidthFraction < minBarFraction ? minBarFraction : barWidthFraction;
    final remainingFraction = 1 - barStartFraction;
    if (remainingFraction <= 0) return 0;
    if (visibleFraction > remainingFraction) return remainingFraction;
    return visibleFraction;
  }

  static String _formatOffset(int ms) => '+${_formatMs(ms)}';

  static String _formatMs(int ms) => '${ms.abs()}ms';
}

/// Private-by-convention viewport for the shared network timeline.
///
/// The range is stored as normalized fractions of the visible timing window.
class DebugNetworkTimelineViewport {
  final double rangeStartFraction;
  final double rangeEndFraction;
  final int? selectedLogEntryId;

  const DebugNetworkTimelineViewport({
    required this.rangeStartFraction,
    required this.rangeEndFraction,
    this.selectedLogEntryId,
  });

  factory DebugNetworkTimelineViewport.full({int? selectedLogEntryId}) {
    return DebugNetworkTimelineViewport(
      rangeStartFraction: 0,
      rangeEndFraction: 1,
      selectedLogEntryId: selectedLogEntryId,
    );
  }

  DebugNetworkTimelineViewport normalized({double minRangeFraction = 0.05}) {
    final start = _clampFraction(rangeStartFraction);
    final end = _clampFraction(rangeEndFraction);
    final orderedStart = start <= end ? start : end;
    final orderedEnd = start <= end ? end : start;
    var adjustedStart = orderedStart;
    var adjustedEnd = orderedEnd;
    final width = adjustedEnd - adjustedStart;
    if (width < minRangeFraction) {
      final desiredWidth = minRangeFraction < 0 ? 0.0 : minRangeFraction;
      adjustedEnd = adjustedStart + desiredWidth;
      if (adjustedEnd > 1) {
        adjustedEnd = 1;
        adjustedStart = 1 - desiredWidth;
      }
      if (adjustedStart < 0) {
        adjustedStart = 0;
        adjustedEnd = desiredWidth;
      }
    }

    return DebugNetworkTimelineViewport(
      rangeStartFraction: adjustedStart,
      rangeEndFraction: adjustedEnd,
      selectedLogEntryId: selectedLogEntryId,
    );
  }

  DebugNetworkTimelineViewport copyWith({
    double? rangeStartFraction,
    double? rangeEndFraction,
    int? selectedLogEntryId,
  }) {
    return DebugNetworkTimelineViewport(
      rangeStartFraction: rangeStartFraction ?? this.rangeStartFraction,
      rangeEndFraction: rangeEndFraction ?? this.rangeEndFraction,
      selectedLogEntryId: selectedLogEntryId ?? this.selectedLogEntryId,
    );
  }

  DebugNetworkTimelineViewport clearSelection() {
    return DebugNetworkTimelineViewport(
      rangeStartFraction: rangeStartFraction,
      rangeEndFraction: rangeEndFraction,
    );
  }

  DebugNetworkTimelineViewport moveByFraction(
    double deltaFraction, {
    double minRangeFraction = 0.05,
  }) {
    final width = rangeEndFraction - rangeStartFraction;
    if (width <= 0) {
      return normalized(minRangeFraction: minRangeFraction);
    }

    var nextStart = rangeStartFraction + deltaFraction;
    var nextEnd = nextStart + width;
    if (nextStart < 0) {
      nextEnd -= nextStart;
      nextStart = 0;
    }
    if (nextEnd > 1) {
      final overshoot = nextEnd - 1;
      nextStart -= overshoot;
      nextEnd = 1;
    }

    return DebugNetworkTimelineViewport(
      rangeStartFraction: nextStart,
      rangeEndFraction: nextEnd,
      selectedLogEntryId: selectedLogEntryId,
    ).normalized(minRangeFraction: minRangeFraction);
  }

  DebugNetworkTimelineViewport resizeLeftToFraction(
    double fraction, {
    double minRangeFraction = 0.05,
  }) {
    final upperBound = rangeEndFraction - minRangeFraction;
    final nextStart = _clampFraction(fraction) > upperBound
        ? upperBound
        : _clampFraction(fraction);
    return DebugNetworkTimelineViewport(
      rangeStartFraction: nextStart < 0 ? 0 : nextStart,
      rangeEndFraction: rangeEndFraction,
      selectedLogEntryId: selectedLogEntryId,
    ).normalized(minRangeFraction: minRangeFraction);
  }

  DebugNetworkTimelineViewport resizeRightToFraction(
    double fraction, {
    double minRangeFraction = 0.05,
  }) {
    final lowerBound = rangeStartFraction + minRangeFraction;
    final nextEnd = _clampFraction(fraction) < lowerBound
        ? lowerBound
        : _clampFraction(fraction);
    return DebugNetworkTimelineViewport(
      rangeStartFraction: rangeStartFraction,
      rangeEndFraction: nextEnd > 1 ? 1 : nextEnd,
      selectedLogEntryId: selectedLogEntryId,
    ).normalized(minRangeFraction: minRangeFraction);
  }

  int rangeStartMs(int windowMs) => (rangeStartFraction * windowMs).round();

  int rangeEndMs(int windowMs) => (rangeEndFraction * windowMs).round();

  int rangeDurationMs(int windowMs) =>
      (rangeEndMs(windowMs) - rangeStartMs(windowMs))
          .clamp(0, windowMs)
          .toInt();

  bool get isFull => rangeStartFraction <= 0 && rangeEndFraction >= 1;

  bool containsRow(DebugNetworkWaterfallRow row, int windowMs) {
    return intersectsRow(row, windowMs);
  }

  bool intersectsRow(
    DebugNetworkWaterfallRow row,
    int windowMs,
  ) {
    final startMs = rangeStartMs(windowMs);
    final endMs = rangeEndMs(windowMs);
    return row.startOffsetMs <= endMs && row.endOffsetMs >= startMs;
  }

  bool intersectsRequestRange(
    DebugNetworkWaterfallRow row,
    int windowStartMs,
    int windowEndMs,
  ) {
    return row.startOffsetMs <= windowEndMs && row.endOffsetMs >= windowStartMs;
  }

  String rangeLabel(int windowMs) {
    if (isFull) return 'Full range';
    return '${rangeStartMs(windowMs)}ms \u2192 ${rangeEndMs(windowMs)}ms';
  }

  String durationLabel(int windowMs) => 'Range: ${rangeDurationMs(windowMs)}ms';

  static double _clampFraction(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}
