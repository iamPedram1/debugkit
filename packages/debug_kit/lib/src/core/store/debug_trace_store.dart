import 'dart:collection';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../models/debug_trace.dart';
import '../models/debug_trace_event.dart';
import '../models/debug_trace_status.dart';

/// Bounded in-memory store for [DebugTrace] instances.
///
/// - Default max traces: 50
/// - Default max events per trace: 200
/// - No UI coupling, no WidgetsBinding in core logic.
/// - Evicts oldest completed traces when the buffer is full.
class DebugTraceStore extends ChangeNotifier {
  final int maxTraces;
  final int maxEventsPerTrace;

  final List<DebugTrace> _traces = [];

  DebugTraceStore({
    this.maxTraces = 50,
    this.maxEventsPerTrace = 200,
  });

  /// All stored traces, newest last.
  UnmodifiableListView<DebugTrace> get traces => UnmodifiableListView(_traces);

  /// Returns the currently running trace with the given [id], or null.
  DebugTrace? getRunningTrace(String id) {
    try {
      return _traces.firstWhere((t) => t.id == id && t.isRunning);
    } catch (_) {
      return null;
    }
  }

  /// Returns any running trace (for active-trace lookup).
  DebugTrace? get activeTrace {
    try {
      return _traces.lastWhere((t) => t.isRunning);
    } catch (_) {
      return null;
    }
  }

  /// Adds a new trace in [DebugTraceStatus.running] state.
  void startTrace(DebugTrace trace) {
    _evictIfNeeded();
    _traces.add(trace);
    _safeNotify();
  }

  /// Appends an event to the trace identified by [traceId].
  ///
  /// Silently ignores if the trace is not found or is no longer running.
  /// Enforces [maxEventsPerTrace] — oldest events are dropped when full.
  void addEvent(String traceId, DebugTraceEvent event) {
    final index = _traces.indexWhere((t) => t.id == traceId);
    if (index == -1) return;

    final trace = _traces[index];
    if (!trace.isRunning) return;

    final currentEvents = List<DebugTraceEvent>.from(trace.events);
    if (currentEvents.length >= maxEventsPerTrace) {
      currentEvents.removeAt(0);
    }
    currentEvents.add(event);

    _traces[index] = trace.copyWith(events: currentEvents);
    _safeNotify();
  }

  /// Marks the trace as [DebugTraceStatus.success] and records [endedAt].
  void finishTrace(String traceId, DateTime endedAt) {
    _updateTrace(
        traceId,
        (t) => t.copyWith(
              status: DebugTraceStatus.success,
              endedAt: endedAt,
            ));
  }

  /// Marks the trace as [DebugTraceStatus.failed] with an optional error summary.
  void failTrace(String traceId, DateTime endedAt, {String? errorSummary}) {
    _updateTrace(
        traceId,
        (t) => t.copyWith(
              status: DebugTraceStatus.failed,
              endedAt: endedAt,
              errorSummary: errorSummary,
            ));
  }

  /// Marks the trace as [DebugTraceStatus.cancelled].
  void cancelTrace(String traceId, DateTime endedAt) {
    _updateTrace(
        traceId,
        (t) => t.copyWith(
              status: DebugTraceStatus.cancelled,
              endedAt: endedAt,
            ));
  }

  /// Removes all stored traces.
  void clear() {
    _traces.clear();
    _safeNotify();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _updateTrace(String traceId, DebugTrace Function(DebugTrace) update) {
    final index = _traces.indexWhere((t) => t.id == traceId);
    if (index == -1) return;
    _traces[index] = update(_traces[index]);
    _safeNotify();
  }

  /// Evicts the oldest *completed* trace when the buffer is full.
  /// If all traces are running, evicts the oldest one regardless.
  void _evictIfNeeded() {
    if (_traces.length < maxTraces) return;

    // Prefer evicting completed traces first
    final completedIndex =
        _traces.indexWhere((t) => t.status != DebugTraceStatus.running);
    if (completedIndex != -1) {
      _traces.removeAt(completedIndex);
    } else {
      _traces.removeAt(0);
    }
  }

  void _safeNotify() {
    if (!hasListeners) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}
