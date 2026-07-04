import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_riverpod/debug_kit_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final counterProvider = NotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
  name: 'counterProvider',
);

final profileProvider = FutureProvider<Map<String, Object?>>(
  (ref) async => {'id': 42, 'name': 'Ada'},
  name: 'profileProvider',
);

void main() {
  DebugKit.init(enabled: kDebugMode);

  runApp(
    ProviderScope(
      observers: [
        DebugKitRiverpodObserver(
          config: DebugKitRiverpodConfig(
            includeValuePreview: true,
            valueSerializer: (value) {
              if (value is AsyncValue) {
                return value.when(
                  data: (data) => {'state': 'data', 'value': data},
                  loading: () => {'state': 'loading'},
                  error: (error, _) => {
                    'state': 'error',
                    'error': error.toString(),
                  },
                );
              }
              return value;
            },
          ),
        ),
      ],
      child: const DebugKitOverlay(child: RiverpodExampleApp()),
    ),
  );
}

class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

class RiverpodExampleApp extends ConsumerWidget {
  const RiverpodExampleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    ref.watch(profileProvider);

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Riverpod example')),
        body: Center(
          child: FilledButton(
            onPressed: () => ref.read(counterProvider.notifier).increment(),
            child: Text('Count: $count'),
          ),
        ),
      ),
    );
  }
}
