import 'dart:collection';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../models/debug_log_entry.dart';
import '../models/debug_log_level.dart';

class DebugLogStore extends ChangeNotifier {
  final int maxLogs;
  final List<DebugLogEntry> _logs = [];
  int _nextId = 1;

  DebugLogStore({this.maxLogs = 300});

  UnmodifiableListView<DebugLogEntry> get logs => UnmodifiableListView(_logs);

  int get errorCount =>
      _logs.where((e) => e.level == DebugLogLevel.error).length;

  void _safeNotify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  void addLog(DebugLogEntry entry) {
    if (_logs.length >= maxLogs) {
      _logs.removeAt(0);
    }
    _logs.add(entry);
    _safeNotify();
  }

  void addLogs(List<DebugLogEntry> entries) {
    for (final entry in entries) {
      if (_logs.length >= maxLogs) {
        _logs.removeAt(0);
      }
      _logs.add(entry);
    }
    _safeNotify();
  }

  void clear() {
    _logs.clear();
    _safeNotify();
  }

  int getNextId() => _nextId++;

  void updateEntry(int id, DebugLogEntry Function(DebugLogEntry) update) {
    final index = _logs.indexWhere((entry) => entry.id == id);
    if (index != -1) {
      _logs[index] = update(_logs[index]);
      _safeNotify();
    }
  }

  DebugLogEntry? getEntryById(int id) {
    try {
      return _logs.firstWhere((entry) => entry.id == id);
    } catch (_) {
      return null;
    }
  }

  DebugLogEntry? getEntryByRequestId(String requestId) {
    try {
      return _logs.firstWhere((entry) => entry.requestId == requestId);
    } catch (_) {
      return null;
    }
  }
}
