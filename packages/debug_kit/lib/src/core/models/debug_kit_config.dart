import 'package:flutter/material.dart';

class DebugKitConfig {
  final bool enabled;
  final int maxLogs;
  final bool captureAppCallLocation;
  final bool captureAppStackTrace;
  final GlobalKey<NavigatorState>? navigatorKey;

  // Trace configuration
  final int maxTraces;
  final int maxTraceEventsPerTrace;
  final Duration slowTraceThreshold;

  const DebugKitConfig({
    this.enabled = true,
    this.maxLogs = 300,
    this.captureAppCallLocation = true,
    this.captureAppStackTrace = false,
    this.navigatorKey,
    this.maxTraces = 50,
    this.maxTraceEventsPerTrace = 200,
    this.slowTraceThreshold = const Duration(seconds: 3),
  });
}
