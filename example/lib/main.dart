import 'package:flutter/material.dart';
import 'package:debug_kit/debug_kit.dart';

void main() {
  // 1. Initialize DebugKit
  DebugKit.init(enabled: true, maxLogs: 500, captureAppStackTrace: true);

  runApp(
    // 2. Wrap your app with DebugKitOverlay
    const DebugKitOverlay(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DebugKit Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'DebugKit Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });

    // 3. Log manual events
    DebugKit.log.info('Counter incremented to $_counter');

    if (_counter % 5 == 0) {
      DebugKit.log.warning('Counter is a multiple of 5');
    }

    if (_counter % 10 == 0) {
      try {
        throw Exception('Simulated counter error at $_counter');
      } catch (e, s) {
        DebugKit.log.error('Something went wrong', error: e, stackTrace: s);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Push the button to generate logs:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                DebugKit.log.userAction(
                  'clicked_demo_button',
                  metadata: {
                    'screen': 'home',
                    'timestamp': DateTime.now().toIso8601String(),
                  },
                );
              },
              child: const Text('Log User Action'),
            ),
            ElevatedButton(
              onPressed: () {
                DebugKit.log.debug(
                  'Debug message with sensitive info: token=eyJhYmNkZWZ0aGlzaXNhdmVyeWxvbmf0b2tlbiJ9',
                );
              },
              child: const Text('Log Sensitive Data (Masked)'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
