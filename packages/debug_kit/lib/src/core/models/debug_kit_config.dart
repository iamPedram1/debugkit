import 'package:flutter/material.dart';

class DebugKitConfig {
  final bool enabled;
  final int maxLogs;
  final bool captureAppCallLocation;
  final bool captureAppStackTrace;
  final GlobalKey<NavigatorState>? navigatorKey;

  const DebugKitConfig({
    this.enabled = true,
    this.maxLogs = 300,
    this.captureAppCallLocation = true,
    this.captureAppStackTrace = false,
    this.navigatorKey,
  });
}
