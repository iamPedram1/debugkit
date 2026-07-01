import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_dio/debug_kit_dio.dart';
import 'package:debug_kit_go_router/debug_kit_go_router.dart';
import 'package:debug_kit_riverpod/debug_kit_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// --- Riverpod Providers ---
final exampleCounterProvider = NotifierProvider<ExampleCounterNotifier, int>(
  ExampleCounterNotifier.new,
  name: 'counterProvider',
);

final exampleAsyncRefreshProvider =
    NotifierProvider<ExampleRefreshNotifier, int>(
  ExampleRefreshNotifier.new,
  name: 'asyncCounterProvider',
);

class ExampleRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

class ExampleBalanceModel {
  final int balance;
  final String currency;

  const ExampleBalanceModel({
    required this.balance,
    required this.currency,
  });

  Map<String, Object?> toJson() => {
        'balance': balance,
        'currency': currency,
      };
}

final exampleAsyncStateProvider =
    FutureProvider<ExampleBalanceModel>((ref) async {
  final refresh = ref.watch(exampleAsyncRefreshProvider);
  await Future.delayed(const Duration(milliseconds: 650));
  return ExampleBalanceModel(balance: 120 + refresh, currency: 'USD');
}, name: 'asyncStateProvider');

class ExampleCounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state++;
  }
}

final exampleStateErrorProvider = Provider<void>((ref) {
  throw Exception('Simulated state error from provider');
}, name: 'stateErrorProvider');

final exampleNestedProfileProvider =
    NotifierProvider<ExampleNestedProfileNotifier, Map<String, Object?>>(
  ExampleNestedProfileNotifier.new,
  name: 'nestedProfileProvider',
);

class ExampleNestedProfileNotifier extends Notifier<Map<String, Object?>> {
  @override
  Map<String, Object?> build() {
    return const <String, Object?>{
      'profile': <String, Object?>{
        'name': 'Pedram',
        'metadata': <String, Object?>{
          'status': 'idle',
          'theme': 'dark',
          'language': 'en',
          'layout': 'grid',
          'notifications': true,
          'density': 'comfortable',
        },
      },
      'flags': <String, Object?>{
        'online': true,
        'betaUser': false,
      },
    };
  }

  void updateNestedKey() {
    final profile = Map<String, Object?>.from(
      state['profile'] as Map<String, Object?>,
    );
    final metadata = Map<String, Object?>.from(
      profile['metadata'] as Map<String, Object?>,
    );
    metadata['status'] = metadata['status'] == 'idle' ? 'active' : 'idle';
    profile['metadata'] = metadata;
    state = <String, Object?>{
      ...state,
      'profile': profile,
    };
  }

  void updateTwoNestedKeys() {
    final profile = Map<String, Object?>.from(
      state['profile'] as Map<String, Object?>,
    );
    final metadata = Map<String, Object?>.from(
      profile['metadata'] as Map<String, Object?>,
    );
    metadata['status'] = metadata['status'] == 'idle' ? 'active' : 'idle';
    metadata['theme'] = metadata['theme'] == 'dark' ? 'light' : 'dark';
    profile['metadata'] = metadata;
    state = <String, Object?>{
      ...state,
      'profile': profile,
    };
  }
}

// Global navigator key for DebugKit integration
final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  final dio = Dio();

  // 1. Initialize DebugKit with trace config
  DebugKit.init(
    enabled: true,
    maxLogs: 500,
    captureAppStackTrace: true,
    navigatorKey: rootNavigatorKey,
    maxTraces: 50,
    maxTraceEventsPerTrace: 200,
    maxStateEvents: 500,
    slowTraceThreshold: const Duration(seconds: 3),
    printToConsole: true,
    consolePrintFormat: DebugConsolePrintFormat.tiny,
    colorizeConsoleOutput: true,
    printManualLogs: true,
    printNetworkLogs: true,
    printRouterLogs: true,
    printRiverpodLogs: true,
    printTraceLogs: true,
    printErrorLogs: true,
    adapters: [
      DebugKitDioAdapter(
        dio,
        config: const DebugKitDioConfig(
          captureRequestHeaders: true,
          captureResponseHeaders: true,
          captureRequestBody: true,
          captureResponseBody: true,
          prettyPrintJson: true,
          decodeGzipBodies: true,
          maxBodyBytes: 65536,
        ),
      ),
    ],
  );

  runApp(
    ProviderScope(
      observers: [
        DebugKitRiverpodObserver(
          config: DebugKitRiverpodConfig(
            recordProviderAdds: true,
            recordProviderUpdates: true,
            recordProviderDisposals: true,
            recordProviderErrors: true,
            mirrorStateChangesToLogs: false,
            mirrorErrorsToLogs: true,
            includeValuePreview: true,
            maxValuePreviewLength: 120,
            valueSerializer: (value) {
              if (value is ExampleBalanceModel) {
                return {
                  'balance': value.balance,
                  'currency': value.currency,
                  'source': 'custom serializer',
                };
              }
              return value;
            },
          ),
        ),
      ],
      child: MyApp(dio: dio),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Dio dio;
  late final GoRouter _router;

  MyApp({super.key, required this.dio}) {
    _router = GoRouter(
      navigatorKey: rootNavigatorKey,
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
      builder: (context, child) => DebugKitOverlay(child: child!),
    );
  }
}

class MyHomePage extends ConsumerWidget {
  final Dio dio;
  const MyHomePage({super.key, required this.dio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(exampleCounterProvider);
    final asyncState = ref.watch(exampleAsyncStateProvider);
    final nestedProfile = ref.watch(exampleNestedProfileProvider);
    final profile = nestedProfile['profile'] as Map<String, Object?>;
    final metadata = profile['metadata'] as Map<String, Object?>;
    final asyncSummary = asyncState.when(
      data: (value) => '${value.balance} ${value.currency}',
      loading: () => 'Loading async state...',
      error: (error, _) => 'Async error: $error',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('DebugKit Showcase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Manual Logs ---
            _SectionTitle('Manual Logs'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(
                onPressed: () => DebugKit.log.debug('This is a debug log'),
                child: const Text('Debug'),
              ),
              ElevatedButton(
                onPressed: () => DebugKit.log.info('This is an info log'),
                child: const Text('Info'),
              ),
              ElevatedButton(
                onPressed: () => DebugKit.log.warning('This is a warning log!'),
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
              ElevatedButton(
                onPressed: () {
                  for (var i = 0; i < 5; i++) {
                    DebugKit.log.warning('Retrying request…');
                  }
                },
                child: const Text('Repeat Log ×5'),
              ),
            ]),
            const Divider(height: 32),

            // --- Traces ---
            _SectionTitle('Traces'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(
                onPressed: () => _runSuccessfulTrace(dio),
                child: const Text('Successful Trace'),
              ),
              ElevatedButton(
                onPressed: () => _runFailedTrace(dio),
                child: const Text('Failed Trace'),
              ),
              ElevatedButton(
                onPressed: () => _runSlowTrace(),
                child: const Text('Slow Trace'),
              ),
              ElevatedButton(
                onPressed: () => _runManualTrace(),
                child: const Text('Manual Trace'),
              ),
              ElevatedButton(
                onPressed: () => _runCancelledTrace(),
                child: const Text('Cancelled Trace'),
              ),
            ]),
            const Divider(height: 32),

            // --- Network (Dio) ---
            _SectionTitle('Network (Dio)'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(
                onPressed: () async {
                  try {
                    await dio.get(
                      'https://pub.dev/api/packages/dio',
                      options: Options(headers: {
                        'X-Debug-Demo': 'network-inspector',
                      }),
                    );
                  } catch (_) {}
                },
                child: const Text('GET Success'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await dio.get(
                        'https://pub.dev/api/packages/invalid_package_123');
                  } catch (_) {}
                },
                child: const Text('GET 404'),
              ),
              ElevatedButton(
                onPressed: () => _runSlowNetworkRequest(dio),
                child: const Text('Slow Request'),
              ),
              ElevatedButton(
                onPressed: () => _runGzipNetworkRequest(dio),
                child: const Text('Gzip JSON'),
              ),
            ]),
            const Divider(height: 32),

            // --- Navigation (GoRouter) ---
            _SectionTitle('Navigation (GoRouter)'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(
                onPressed: () => context.push('/details?token=secret_token'),
                child: const Text('Push /details'),
              ),
              ElevatedButton(
                onPressed: () => context.go('/details'),
                child: const Text('Replace Route'),
              ),
            ]),
            const Divider(height: 32),

            // --- State (Riverpod) ---
            _SectionTitle('State (Riverpod)'),
            Text('Counter: $counter', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Async balance: $asyncSummary',
              style: const TextStyle(fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Nested: ${metadata['status']} • ${nestedProfile['flags']}',
              style: const TextStyle(fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(
                onPressed: () =>
                    ref.read(exampleCounterProvider.notifier).increment(),
                child: const Text('Increment State'),
              ),
              ElevatedButton(
                onPressed: () =>
                    ref.read(exampleAsyncRefreshProvider.notifier).increment(),
                child: const Text('Refresh Async Balance'),
              ),
              ElevatedButton(
                onPressed: () {
                  try {
                    ref.read(exampleStateErrorProvider);
                  } catch (_) {}
                },
                child: const Text('Trigger State Error'),
              ),
              ActionChip(
                label: const Text('Update Nested Key'),
                onPressed: () => ref
                    .read(exampleNestedProfileProvider.notifier)
                    .updateNestedKey(),
              ),
              ActionChip(
                label: const Text('Update 2 Nested Keys'),
                onPressed: () => ref
                    .read(exampleNestedProfileProvider.notifier)
                    .updateTwoNestedKeys(),
              ),
              ElevatedButton(
                onPressed: () {
                  DebugKit.state.record(
                    DebugStateEvent(
                      id: 'manual-state-${DateTime.now().millisecondsSinceEpoch}',
                      timestamp: DateTime.now(),
                      source: 'app',
                      name: 'manualAnnotation',
                      eventType: DebugStateEventType.updated,
                      nextValuePreview: 'user_tapped_button',
                      metadata: {'screen': 'example_home'},
                    ),
                  );
                },
                child: const Text('Record Custom State'),
              ),
              ElevatedButton(
                onPressed: () => DebugKit.open(),
                child: const Text('Open DebugKit'),
              ),
            ]),
            const Divider(height: 32),

            // --- DebugKit Controls ---
            _SectionTitle('DebugKit'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(
                onPressed: () => DebugKit.clearLogs(),
                child: const Text('Clear Logs'),
              ),
              ElevatedButton(
                onPressed: () => DebugKit.clearStateEvents(),
                child: const Text('Clear State'),
              ),
              ElevatedButton(
                onPressed: () => DebugKit.clearTraces(),
                child: const Text('Clear Traces'),
              ),
            ]),

            const Divider(height: 32),

            // --- Error Digest Demo ---
            _SectionTitle('Error Digest'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(
                onPressed: () {
                  // Repeated error — should group in digest
                  for (var i = 0; i < 5; i++) {
                    DebugKit.log.error(
                      'Auth token expired',
                      error:
                          Exception('InvalidTokenException: token has expired'),
                    );
                  }
                },
                child: const Text('Repeated Error ×5'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Unique error — different type
                  DebugKit.log.error(
                    'Failed to parse response',
                    error: Exception('FormatException: unexpected character'),
                  );
                },
                child: const Text('Unique Error'),
              ),
              ElevatedButton(
                onPressed: () => _runFailedDigestTrace(),
                child: const Text('Failed Trace Error'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await dio.get(
                        'https://pub.dev/api/packages/nonexistent_xyz_404');
                  } catch (_) {}
                },
                child: const Text('Dio 404 Error'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trace demos
  // ---------------------------------------------------------------------------

  Future<void> _runSuccessfulTrace(Dio dio) async {
    await DebugKit.trace.run(
      'fetch_packages',
      () async {
        DebugKit.trace.step('start_request');
        DebugKit.log.info('Fetching package list');
        try {
          await dio.get('https://pub.dev/api/packages/flutter');
        } catch (_) {}
        DebugKit.trace.step('request_complete');
        DebugKit.log.info('Package list fetched');
      },
      metadata: {'source': 'home_page'},
    );
  }

  Future<void> _runFailedTrace(Dio dio) async {
    try {
      await DebugKit.trace.run(
        'login_flow',
        () async {
          DebugKit.trace.step('validate_credentials');
          DebugKit.log.info('Validating credentials');
          try {
            await dio
                .get('https://pub.dev/api/packages/invalid_package_xyz_123');
          } catch (_) {}
          DebugKit.trace.step('auth_request');
          throw Exception('Authentication failed: invalid credentials');
        },
        metadata: {'screen': 'login'},
      );
    } catch (_) {
      // Expected — trace.run rethrows
    }
  }

  Future<void> _runSlowTrace() async {
    await DebugKit.trace.run(
      'slow_operation',
      () async {
        DebugKit.trace.step('heavy_computation');
        DebugKit.log.info('Starting slow operation...');
        await Future.delayed(const Duration(seconds: 4));
        DebugKit.trace.step('computation_done');
        DebugKit.log.info('Slow operation complete');
      },
      metadata: {'type': 'background_task'},
    );
  }

  void _runManualTrace() {
    final traceId = DebugKit.trace.start(
      'manual_checkout',
      metadata: {'cart_items': '3'},
    );
    DebugKit.trace.step('validate_cart', traceId: traceId);
    DebugKit.log.info('Cart validated');
    DebugKit.trace.step('apply_discount', traceId: traceId);
    DebugKit.log.info('Discount applied');
    DebugKit.trace.end(traceId: traceId);
  }

  void _runCancelledTrace() {
    final traceId = DebugKit.trace.start('upload_flow');
    DebugKit.trace.step('prepare_upload', traceId: traceId);
    DebugKit.log.info('Upload prepared');
    DebugKit.trace.cancel('user_cancelled', traceId: traceId);
  }

  Future<void> _runFailedDigestTrace() async {
    try {
      await DebugKit.trace.run(
        'checkout_flow',
        () async {
          DebugKit.trace.step('validate_cart');
          DebugKit.log.error(
            'Cart validation failed',
            error: Exception('ValidationException: item out of stock'),
          );
          throw Exception('Cart validation failed — item out of stock');
        },
        metadata: {'source': 'checkout_button'},
      );
    } catch (_) {
      // Expected
    }
  }

  Future<void> _runSlowNetworkRequest(Dio dio) async {
    final previousAdapter = dio.httpClientAdapter;
    dio.httpClientAdapter = _SlowMockAdapter(
      delay: const Duration(milliseconds: 900),
      body: '{"status":"ok","demo":"slow"}',
      statusCode: 200,
    );

    try {
      await dio.get('https://api.example.com/demo/slow');
    } catch (_) {
      // Expected to stay silent if the temporary adapter changes behavior.
    } finally {
      dio.httpClientAdapter = previousAdapter;
    }
  }

  Future<void> _runGzipNetworkRequest(Dio dio) async {
    final previousAdapter = dio.httpClientAdapter;
    dio.httpClientAdapter = _GzipMockAdapter(
      delay: const Duration(milliseconds: 250),
      body: '{"status":"ok","demo":"gzip"}',
      statusCode: 200,
    );

    try {
      await dio.post(
        'https://api.example.com/demo/gzip',
        data: gzip.encode(utf8.encode('{"request":"gzip"}')),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            Headers.contentTypeHeader: Headers.jsonContentType,
            Headers.contentEncodingHeader: 'gzip',
          },
        ),
      );
    } catch (_) {
      // Expected to stay silent if the temporary adapter changes behavior.
    } finally {
      dio.httpClientAdapter = previousAdapter;
    }
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          child: const Text('Pop or Go Home'),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}

class _SlowMockAdapter implements HttpClientAdapter {
  final Duration delay;
  final String body;
  final int statusCode;

  _SlowMockAdapter({
    required this.delay,
    required this.body,
    required this.statusCode,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(delay);
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'x-request-id': ['demo-slow-request'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _GzipMockAdapter implements HttpClientAdapter {
  final Duration delay;
  final String body;
  final int statusCode;

  _GzipMockAdapter({
    required this.delay,
    required this.body,
    required this.statusCode,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(delay);
    return ResponseBody.fromBytes(
      gzip.encode(utf8.encode(body)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        Headers.contentEncodingHeader: ['gzip'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
