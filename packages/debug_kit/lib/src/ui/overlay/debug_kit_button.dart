import 'package:flutter/material.dart';
import '../../core/controller/debug_kit_controller.dart';
import '../screens/debug_kit_console_screen.dart';

/// The draggable floating debug button shown by [DebugKitOverlay].
class DebugKitButton extends StatefulWidget {
  const DebugKitButton({super.key});

  @override
  State<DebugKitButton> createState() => _DebugKitButtonState();
}

class _DebugKitButtonState extends State<DebugKitButton> {
  // Stores the absolute position of the button's top-left corner.
  // Initialised on first layout using WidgetsBinding.
  Offset? _position;

  static const double _buttonSize = 56.0;
  static const double _edgePadding = 16.0;

  @override
  void initState() {
    super.initState();
    // Defer initial position until first frame so we have screen dimensions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);
      setState(() {
        _position = Offset(
          size.width - _buttonSize - _edgePadding,
          size.height * 0.6,
        );
      });
    });
  }

  void _clampPosition(Size screenSize) {
    if (_position == null) return;
    _position = Offset(
      _position!.dx
          .clamp(_edgePadding, screenSize.width - _buttonSize - _edgePadding),
      _position!.dy
          .clamp(_edgePadding, screenSize.height - _buttonSize - _edgePadding),
    );
  }

  void _openConsole(BuildContext context) {
    NavigatorState? navigator = Navigator.maybeOf(context);

    if (navigator == null) {
      final config = DebugKitController().config;
      if (config.navigatorKey != null) {
        navigator = config.navigatorKey!.currentState;
      }
    }

    if (navigator != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const DebugKitConsoleScreen(),
          settings: const RouteSettings(name: 'debug_kit_console'),
        ),
      );
    } else {
      // ignore: avoid_print
      print(
          'DebugKit: Could not find Navigator. Ensure you are calling this from a context '
          'descended from Navigator or provide a navigatorKey during DebugKit.init().');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_position == null) return const SizedBox.shrink();

    final screenSize = MediaQuery.sizeOf(context);

    return ListenableBuilder(
      listenable: DebugKitController().store,
      builder: (context, _) {
        final store = DebugKitController().store;
        final errorCount = store.errorCount;
        final hasErrors = errorCount > 0;

        return Positioned(
          left: _position!.dx,
          top: _position!.dy,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              setState(() {
                _position = _position! + details.delta;
                _clampPosition(screenSize);
              });
            },
            onTap: () => _openConsole(context),
            child: SizedBox(
              width: _buttonSize + 10, // Extra touch area
              height: _buttonSize + 10,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: _buttonSize,
                      height: _buttonSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: hasErrors
                              ? [
                                  const Color(0xFF7F0000),
                                  const Color(0xFF1A0000)
                                ]
                              : [
                                  const Color(0xFF2D2D2D),
                                  const Color(0xFF1A1A1A)
                                ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: hasErrors
                                ? Colors.red.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: hasErrors
                              ? Colors.red.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.bug_report_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    if (hasErrors)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            errorCount > 99 ? '99+' : errorCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
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
          ),
        );
      },
    );
  }
}
