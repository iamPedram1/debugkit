import '../../core/models/debug_network_transaction.dart';

/// Timing geometry for the lightweight network waterfall visualization.
class DebugNetworkWaterfallMetrics {
  final DateTime windowStart;
  final int windowMs;
  final List<DebugNetworkWaterfallRow> rows;

  const DebugNetworkWaterfallMetrics({
    required this.windowStart,
    required this.windowMs,
    required this.rows,
  });

  static DebugNetworkWaterfallMetrics fromTransactions(
    List<DebugNetworkTransaction> transactions, {
    double minBarFraction = 0.06,
  }) {
    if (transactions.isEmpty) {
      return DebugNetworkWaterfallMetrics(
        windowStart: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        windowMs: 1,
        rows: [],
      );
    }

    final ordered = [...transactions]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final firstStart = ordered.first.startedAt;

    var latestEnd = firstStart;
    for (final transaction in ordered) {
      final end = transaction.completedAt ?? transaction.startedAt;
      if (end.isAfter(latestEnd)) {
        latestEnd = end;
      }
    }

    final windowMs =
        _clampWindowMs(latestEnd.difference(firstStart).inMilliseconds);
    final rows = ordered.map((transaction) {
      final startOffsetMs =
          transaction.startedAt.difference(firstStart).inMilliseconds;
      final durationMs = transaction.durationMs ?? 0;
      final barStartFraction = startOffsetMs / windowMs;
      var barWidthFraction =
          durationMs <= 0 ? minBarFraction : durationMs / windowMs;
      final isPending = transaction.isPending;
      if (barWidthFraction < minBarFraction) {
        barWidthFraction = minBarFraction;
      }

      if (barStartFraction + barWidthFraction > 1) {
        barWidthFraction = 1 - barStartFraction;
      }

      return DebugNetworkWaterfallRow(
        transaction: transaction,
        startOffsetMs: startOffsetMs,
        barStartFraction: barStartFraction.clamp(0.0, 1.0).toDouble(),
        barWidthFraction: barWidthFraction.clamp(0.0, 1.0).toDouble(),
        isPending: isPending,
      );
    }).toList(growable: false);

    return DebugNetworkWaterfallMetrics(
      windowStart: firstStart,
      windowMs: windowMs,
      rows: rows,
    );
  }

  static int _clampWindowMs(int windowMs) {
    if (windowMs <= 0) return 1;
    return windowMs;
  }
}

/// Per-row waterfall geometry.
class DebugNetworkWaterfallRow {
  final DebugNetworkTransaction transaction;
  final int startOffsetMs;
  final double barStartFraction;
  final double barWidthFraction;
  final bool isPending;

  const DebugNetworkWaterfallRow({
    required this.transaction,
    required this.startOffsetMs,
    required this.barStartFraction,
    required this.barWidthFraction,
    required this.isPending,
  });
}
