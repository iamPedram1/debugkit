import 'package:flutter/material.dart';
import '../../core/controller/debug_kit_controller.dart';
import 'debug_kit_button.dart';

class DebugKitOverlay extends StatelessWidget {
  final Widget child;

  const DebugKitOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugKitController(),
      builder: (context, _) {
        final config = DebugKitController().config;
        if (!config.enabled) return child;

        return Stack(
          children: [
            child,
            const Positioned(
              right: 20,
              bottom: 100,
              child: DebugKitButton(),
            ),
          ],
        );
      },
    );
  }
}
