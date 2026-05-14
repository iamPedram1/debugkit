import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_dio/debug_kit_dio.dart';

void main() {
  final dio = Dio();

  // 1. Initialize DebugKit
  DebugKit.init(
    enabled: true,
    maxLogs: 500,
    captureAppStackTrace: true,
    adapters: [
      DebugKitDioAdapter(dio),
    ],
  );

  runApp(
    // 2. Wrap your app with DebugKitOverlay
    DebugKitOverlay(child: MyApp(dio: dio)),
  );
}

class MyApp extends StatelessWidget {
  final Dio dio;
  const MyApp({super.key, required this.dio});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DebugKit Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'DebugKit Demo', dio: dio),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final Dio dio;
  const MyHomePage({super.key, required this.title, required this.dio});

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
            const Divider(),
            const Text('Network Actions (Dio):'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await widget.dio
                          .get('https://pub.dev/api/packages/debug_kit');
                    } catch (_) {}
                  },
                  child: const Text('GET Success'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await widget.dio.get(
                          'https://pub.dev/api/packages/invalid_package_123');
                    } catch (_) {}
                  },
                  child: const Text('GET 404'),
                ),
              ],
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
