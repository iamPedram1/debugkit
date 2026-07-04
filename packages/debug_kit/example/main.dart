import 'package:debug_kit/debug_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  DebugKit.init(
    enabled: kDebugMode,
    maxLogs: 300,
    disableDefaultOverlayButton: false,
  );

  runApp(const DebugKitOverlay(child: DebugKitExampleApp()));
}

class DebugKitExampleApp extends StatelessWidget {
  const DebugKitExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('DebugKit example')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () {
                  DebugKit.log.info(
                    'Manual log from the example app',
                    metadata: const {'screen': 'home'},
                  );
                },
                child: const Text('Write log'),
              ),
              const SizedBox(height: 12),
              const OutlinedButton(
                onPressed: DebugKit.open,
                child: Text('Open DebugKit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
