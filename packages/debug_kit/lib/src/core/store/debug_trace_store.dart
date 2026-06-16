import 'dart:collection';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../models/debug_trace.dart';
import '../models/debug_trace_event.dart';
import '../models/debug_trace_status.dart';

/// Bounded in-memory store for [DebugTrace] instances.
///
/// Notifies [ChangeNotifier] listeners when the trace list changes so the
/// console UI can rebuild reactively. Like [DebugLogStore], notifications are
/// deferred during frame builds to prevent "setState during build" errors.
///
/// **Eviction policy**: when [maxTraces] is reached, the oldest *completed*
/// (non-running) trace is dropped first. If every trace is still running, the
/// oldest trace is dropped regardless.
///
/// The store is accessed via [DebugKitController.traceStore]. Direct
/// construction is for tests only.
class DebugTraceStore extends ChangeNotifier {
  /// Maximum number of [DebugTrace] instances kept in memory.
  ///
  /// Defaults to `50`.
  final int maxTraces;

  /// Maximum number of [DebugTraceEvent] instances per trace.
  ///
  /// When a trace reaches this limit, the oldest event is dropped before the
  /// newest is appended.
  /// Defaults to `200`.
  final int maxEventsPerTrace;

  final List<DebugTrace> _traces = [];

  /// Creates a [DebugTraceStore] with the given capacity limits.
  DebugTraceStore({
    this.maxTraces = 50,
    this.maxEventsPerTrace = 200,
  });

  /// All stored traces in insertion order (oldest first).
  ///
  /// Returns an unmodifiable view — mutate via [startTrace], [addEvent],
  /// [finishTrace], [failTrace], [cancelTrace], or [clear].
  UnmodifiableListView<DebugTrace> get traces => UnmodifiableListView(_traces);

  /// Returns the running trace with the given [id], or `null` if not found or
  /// already completed.
  DebugTrace? getRunningTrace(String id) {
    try {
      return _traces.firstWhere((t) => t.id == id && t.isRunning);
    } catch (_) {
      return null;
    }
  }

  /// Returns the most recently started trace that is still running, or `null`.
  ///
  /// Used by [DebugTraceController] as a fallback when no Zone-based trace ID
  /// is available.
  DebugTrace? get activeTrace {
    try {
      return _traces.lastWhere((t) => t.isRunning);
    } catch (_) {
      return null;
    }
  }

  /// Adds [trace] (which must be in [DebugTraceStatus.running] state) to the
  /// store, evicting an old entry if the buffer is full.
  void startTrace(DebugTrace trace) {
    _evictIfNeeded();
    _traces.add(trace);
    _safeNotify();
  }

  /// Appends [event] to the trace identified by [traceId].
  ///
  /// Silently ignores the call if:
  /// - no trace with [traceId] exists, or
  /// - the trace is no longer in [DebugTraceStatus.running] state.
  ///
  /// Enforces [maxEventsPerTrace] by dropping the oldest event first when the
  /// per-trace limit is reached.
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

  /// Transitions the trace identified by [traceId] to [DebugTraceStatus.success]
  /// and records [endedAt] as the completion timestamp.
  ///
  /// No-op if [traceId] is not found.
  void finishTrace(String traceId, DateTime endedAt) {
    _updateTrace(
      traceId,
      (t) => t.copyWith(
        status: DebugTraceStatus.success,
        endedAt: endedAt,
      ),
    );
  }

  /// Transitions the trace identified by [traceId] to [DebugTraceStatus.failed]
  /// and records [endedAt] and an optional [errorSummary].
  ///
  /// No-op if [traceId] is not found.
  void failTrace(String traceId, DateTime endedAt, {String? errorSummary}) {
    _updateTrace(
      traceId,
      (t) => t.copyWith(
        status: DebugTraceStatus.failed,
        endedAt: endedAt,
        errorSummary: errorSummary,
      ),
    );
  }

  /// Transitions the trace identified by [traceId] to [DebugTraceStatus.cancelled]
  /// and records [endedAt].
  ///
  /// No-op if [traceId] is not found.
  void cancelTrace(String traceId, DateTime endedAt) {
    _updateTrace(
      traceId,
      (t) => t.copyWith(
        status: DebugTraceStatus.cancelled,
        endedAt: endedAt,
      ),
    );
  }

  /// Removes all stored traces and notifies listeners.
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

  /// Evicts one trace from the buffer when [maxTraces] is reached.
  ///
  /// Prefers to remove the oldest completed trace. Falls back to evicting the
  /// oldest trace regardless of status.
  void _evictIfNeeded() {
    if (_traces.length < maxTraces) return;

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
