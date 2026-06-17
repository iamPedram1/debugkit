import 'dart:collection';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../models/debug_log_entry.dart';
import '../models/debug_log_level.dart';

/// Bounded in-memory store for [DebugLogEntry] instances.
///
/// Notifies [ChangeNotifier] listeners whenever the log list changes so that
/// the console UI can rebuild reactively. Notifications are deferred with
/// [SchedulerBinding.addPostFrameCallback] when called during a frame build to
/// avoid "setState during build" errors.
///
/// **Repeat grouping:** when [groupRepeated] is `true` (the default), calling
/// [addLog] with an entry whose [DebugLogEntry.fingerprint] matches the tail
/// entry will increment [DebugLogEntry.repeatCount] on the tail rather than
/// appending a new row. This keeps the store bounded and mirrors Chrome
/// DevTools console behavior.
///
/// The store is a singleton accessed via [DebugKitController.store]. Direct
/// construction is for tests only.
class DebugLogStore extends ChangeNotifier {
  /// Maximum number of entries kept in memory.
  ///
  /// Grouped entries count as one slot regardless of [DebugLogEntry.repeatCount].
  /// When [addLog] is called and the buffer is full, the oldest entry is
  /// evicted before the new one is appended.
  final int maxLogs;

  /// Whether to group consecutive identical entries.
  ///
  /// Mirrors [DebugKitConfig.groupRepeatedLogs]. Injected at construction so
  /// tests can toggle the behavior without touching global config.
  final bool groupRepeated;

  final List<DebugLogEntry> _logs = [];
  int _nextId = 1;

  /// Creates a [DebugLogStore].
  ///
  /// - [maxLogs]: buffer capacity. Defaults to `300`.
  /// - [groupRepeated]: enable consecutive-duplicate grouping. Defaults to `true`.
  DebugLogStore({this.maxLogs = 300, this.groupRepeated = true});

  /// All stored entries in insertion order (oldest first).
  ///
  /// Returns an unmodifiable view — mutate via [addLog], [addLogs], [clear],
  /// or [updateEntry].
  UnmodifiableListView<DebugLogEntry> get logs => UnmodifiableListView(_logs);

  /// Number of entries with [DebugLogLevel.error] currently in the store.
  ///
  /// Used by the overlay button to display a red badge.
  int get errorCount =>
      _logs.where((e) => e.level == DebugLogLevel.error).length;

  /// Notifies listeners safely regardless of the current scheduler phase.
  ///
  /// Defers notification via [addPostFrameCallback] when called during a
  /// frame's build / layout / paint phase to prevent "setState during build".
  void _safeNotify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  /// Appends [entry] to the store, with optional consecutive-duplicate grouping.
  ///
  /// **Grouping path** (when [groupRepeated] is `true`):
  /// 1. The entry is eligible for grouping only if it has **no `requestId`**.
  ///    Entries with a `requestId` are individually addressable by the Dio
  ///    adapter via [getEntryByRequestId] and must never be merged — doing so
  ///    would cause [updateLogByRequestId] to silently lose network updates.
  /// 2. If eligible and the tail entry has the same [DebugLogEntry.fingerprint],
  ///    the tail is replaced with [DebugLogEntry.copyWithRepeatIncrement] and
  ///    listeners are notified. No new row is appended.
  ///
  /// **Normal path** (grouping disabled, entry has a requestId, or fingerprints differ):
  /// 1. Evicts the oldest entry if the buffer is full.
  /// 2. Appends [entry].
  /// 3. Notifies listeners.
  void addLog(DebugLogEntry entry) {
    if (groupRepeated && _logs.isNotEmpty && entry.requestId == null) {
      final tail = _logs.last;
      if (tail.fingerprint == entry.fingerprint) {
        _logs[_logs.length - 1] = tail.copyWithRepeatIncrement(DateTime.now());
        _safeNotify();
        return;
      }
    }

    if (_logs.length >= maxLogs) {
      _logs.removeAt(0);
    }
    _logs.add(entry);
    _safeNotify();
  }

  /// Appends multiple [entries] at once, applying grouping and eviction for
  /// each entry in order.
  ///
  /// Only one [notifyListeners] call is made after all entries are processed.
  void addLogs(List<DebugLogEntry> entries) {
    for (final entry in entries) {
      if (groupRepeated && _logs.isNotEmpty && entry.requestId == null) {
        final tail = _logs.last;
        if (tail.fingerprint == entry.fingerprint) {
          _logs[_logs.length - 1] =
              tail.copyWithRepeatIncrement(DateTime.now());
          continue;
        }
      }
      if (_logs.length >= maxLogs) {
        _logs.removeAt(0);
      }
      _logs.add(entry);
    }
    _safeNotify();
  }

  /// Removes all entries from the store and notifies listeners.
  void clear() {
    _logs.clear();
    _safeNotify();
  }

  /// Returns the next monotonically increasing entry ID and advances the counter.
  ///
  /// Called by [DebugKitController.log] when constructing a [DebugLogEntry].
  int getNextId() => _nextId++;

  /// Replaces the entry with [id] using the result of [update].
  ///
  /// No-op if no entry with [id] exists. Used by the Dio adapter to finalize
  /// a pending log with the response status code and duration.
  void updateEntry(int id, DebugLogEntry Function(DebugLogEntry) update) {
    final index = _logs.indexWhere((entry) => entry.id == id);
    if (index != -1) {
      _logs[index] = update(_logs[index]);
      _safeNotify();
    }
  }

  /// Returns the entry with the given internal [id], or `null`.
  DebugLogEntry? getEntryById(int id) {
    try {
      return _logs.firstWhere((entry) => entry.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns the first entry whose [DebugLogEntry.requestId] matches
  /// [requestId], or `null`.
  ///
  /// Used by the Dio adapter to locate the pending log entry when a response
  /// or error arrives.
  DebugLogEntry? getEntryByRequestId(String requestId) {
    try {
      return _logs.firstWhere((entry) => entry.requestId == requestId);
    } catch (_) {
      return null;
    }
  }
}
