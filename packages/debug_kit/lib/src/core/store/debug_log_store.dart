import 'dart:collection';
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

  void addLog(DebugLogEntry entry) {
    if (_logs.length >= maxLogs) {
      _logs.removeAt(0);
    }
    _logs.add(entry);
    notifyListeners();
  }

  void addLogs(List<DebugLogEntry> entries) {
    for (final entry in entries) {
      if (_logs.length >= maxLogs) {
        _logs.removeAt(0);
      }
      _logs.add(entry);
    }
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  int getNextId() => _nextId++;

  void updateEntry(int id, DebugLogEntry Function(DebugLogEntry) update) {
    final index = _logs.indexWhere((entry) => entry.id == id);
    if (index != -1) {
      _logs[index] = update(_logs[index]);
      notifyListeners();
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
