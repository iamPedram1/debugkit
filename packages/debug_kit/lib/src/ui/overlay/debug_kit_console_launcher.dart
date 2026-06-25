import 'package:flutter/material.dart';

import '../../core/controller/debug_kit_controller.dart';
import '../screens/debug_kit_console_screen.dart';

bool _consoleRouteOpen = false;
NavigatorState? _consoleNavigator;

void resetDebugKitConsoleLauncherState() {
  _consoleRouteOpen = false;
  _consoleNavigator = null;
}

void openDebugKitConsole({BuildContext? context}) {
  final controller = DebugKitController();
  if (!controller.config.enabled || _consoleRouteOpen) return;

  NavigatorState? navigator;
  if (context != null) {
    navigator = Navigator.maybeOf(context);
  }
  navigator ??= controller.config.navigatorKey?.currentState;

  if (navigator == null) return;

  _consoleRouteOpen = true;
  _consoleNavigator = navigator;
  navigator
      .push(
    MaterialPageRoute(
      builder: (_) => const DebugKitConsoleScreen(),
      settings: const RouteSettings(name: 'debug_kit_console'),
    ),
  )
      .whenComplete(() {
    _consoleRouteOpen = false;
    _consoleNavigator = null;
  });
}

void closeDebugKitConsole() {
  if (!_consoleRouteOpen) return;

  final navigator = _consoleNavigator ??
      DebugKitController().config.navigatorKey?.currentState;
  if (navigator == null) return;

  _consoleRouteOpen = false;
  _consoleNavigator = null;
  navigator.maybePop();
}

bool get isDebugKitConsoleOpen => _consoleRouteOpen;
