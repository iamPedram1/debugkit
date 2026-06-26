import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../models/debug_state_event.dart';

/// Bounded in-memory store for [DebugStateEvent] instances.
///
/// State events are kept separate from normal logs so high-frequency provider
/// updates do not pollute the Logs tab.
class DebugStateStore extends ChangeNotifier {
  /// Maximum number of events kept in memory.
  final int maxEvents;

  final List<DebugStateEvent> _events = [];
  int _nextId = 1;

  /// Creates a [DebugStateStore].
  DebugStateStore({this.maxEvents = 500});

  /// All stored events in insertion order.
  UnmodifiableListView<DebugStateEvent> get events =>
      UnmodifiableListView(_events);

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

  void addEvent(DebugStateEvent event) {
    if (maxEvents <= 0) return;
    if (_events.length >= maxEvents) {
      _events.removeAt(0);
    }
    _events.add(event);
    _safeNotify();
  }

  void clear() {
    if (_events.isEmpty) return;
    _events.clear();
    _safeNotify();
  }

  int getNextId() => _nextId++;
}
