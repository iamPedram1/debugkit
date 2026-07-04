import 'package:flutter/material.dart';
import '../../core/controller/debug_kit_controller.dart';
import 'debug_kit_button.dart';

/// Wraps your app and shows the [DebugKitButton] overlay when DebugKit is enabled
/// unless the default launcher button has been disabled in [DebugKitConfig].
///
/// Place this as close to the root of your widget tree as possible:
/// ```dart
/// runApp(const DebugKitOverlay(child: MyApp()));
/// ```
class DebugKitOverlay extends StatelessWidget {
  /// The application subtree that DebugKit should wrap.
  final Widget child;

  /// Creates an overlay wrapper for the host app.
  ///
  /// When DebugKit is disabled, or the default overlay button is disabled,
  /// [child] is returned unchanged.
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
        if (config.disableDefaultOverlayButton) return child;

        return Stack(
          children: [
            child,
            // DebugKitButton manages its own absolute position internally.
            const DebugKitButton(),
          ],
        );
      },
    );
  }
}
