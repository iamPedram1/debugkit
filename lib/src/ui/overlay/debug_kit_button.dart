import 'package:flutter/material.dart';
import '../../core/controller/debug_kit_controller.dart';
import '../../core/models/debug_log_level.dart';
import '../screens/debug_kit_console_screen.dart';

class DebugKitButton extends StatefulWidget {
  const DebugKitButton({super.key});

  @override
  State<DebugKitButton> createState() => _DebugKitButtonState();
}

class _DebugKitButtonState extends State<DebugKitButton> {
  Offset _offset = const Offset(0, 0);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugKitController().store,
      builder: (context, _) {
        final logs = DebugKitController().store.logs;
        final errorCount =
            logs.where((e) => e.level == DebugLogLevel.error).length;

        return Transform.translate(
          offset: _offset,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _offset += details.delta;
              });
            },
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DebugKitConsoleScreen(),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.grey[800]!,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.bug_report,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  if (errorCount > 0)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          errorCount > 99 ? '99+' : errorCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
