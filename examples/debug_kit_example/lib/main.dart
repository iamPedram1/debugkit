import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_dio/debug_kit_dio.dart';
import 'package:debug_kit_go_router/debug_kit_go_router.dart';
import 'package:debug_kit_riverpod/debug_kit_riverpod.dart';

// --- Riverpod Providers ---
final exampleCounterProvider = StateProvider<int>((ref) => 0);
final throwingProvider = Provider<String>((ref) {
  throw Exception('Simulated Riverpod Provider Failure!');
});

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
    // 2. Wrap app with ProviderScope and add DebugKitRiverpodObserver
    ProviderScope(
      observers: [
        DebugKitRiverpodObserver(
          config: const DebugKitRiverpodConfig(
            logProviderUpdates: true, // Enable for demo
            includeValuePreview: true,
          ),
        ),
      ],
      // 3. Wrap with DebugKitOverlay
      child: DebugKitOverlay(
        child: MyApp(dio: dio),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Dio dio;
  late final GoRouter _router;

  MyApp({super.key, required this.dio}) {
    // 4. Configure GoRouter with DebugKitGoRouterObserver
    _router = GoRouter(
      observers: [DebugKitGoRouterObserver()],
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MyHomePage(dio: dio),
        ),
        GoRoute(
          path: '/details',
          builder: (context, state) => const DetailsPage(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DebugKit Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

class MyHomePage extends ConsumerWidget {
  final Dio dio;
  const MyHomePage({super.key, required this.dio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(exampleCounterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DebugKit Showcase'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Manual Logs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => DebugKit.log.debug('This is a debug log'),
                  child: const Text('Debug'),
                ),
                ElevatedButton(
                  onPressed: () => DebugKit.log.info('This is an info log'),
                  child: const Text('Info'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      DebugKit.log.warning('This is a warning log!'),
                  child: const Text('Warning'),
                ),
                ElevatedButton(
                  onPressed: () => DebugKit.log
                      .error('This is an error log!', error: Exception('Oops')),
                  child: const Text('Error'),
                ),
                ElevatedButton(
                  onPressed: () => DebugKit.log
                      .info('User password is: my_super_secret_password123'),
                  child: const Text('Sensitive Log'),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Network (Dio)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () =>
                      dio.get('https://pub.dev/api/packages/debug_kit'),
                  child: const Text('GET Success'),
                ),
                ElevatedButton(
                  onPressed: () => dio
                      .get('https://pub.dev/api/packages/invalid_package_123'),
                  child: const Text('GET 404'),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Navigation (GoRouter)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => context.push('/details?token=secret_token'),
                  child: const Text('Push /details'),
                ),
                ElevatedButton(
                  onPressed: () => context.go('/details'),
                  child: const Text('Replace Route'),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('State (Riverpod)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Counter: $counter', style: const TextStyle(fontSize: 16)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () =>
                      ref.read(exampleCounterProvider.notifier).state++,
                  child: const Text('Update Provider'),
                ),
                ElevatedButton(
                  onPressed: () {
                    try {
                      ref.read(throwingProvider);
                    } catch (_) {}
                  },
                  child: const Text('Trigger Failure'),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('DebugKit',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => DebugKit.controller.store.clear(),
                  child: const Text('Clear Logs'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.pop(),
          child: const Text('Pop Route'),
        ),
      ),
    );
  }
}
