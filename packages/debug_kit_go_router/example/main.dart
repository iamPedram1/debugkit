import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_go_router/debug_kit_go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _router = GoRouter(
  observers: [DebugKitGoRouterObserver()],
  routes: [
    GoRoute(
      name: 'home',
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          name: 'profile',
          path: 'profile/:id',
          builder: (context, state) {
            final userId = state.pathParameters['id']!;
            final tab = state.uri.queryParameters['tab'] ?? 'overview';
            return ProfileScreen(userId: userId, tab: tab);
          },
        ),
      ],
    ),
  ],
);

void main() {
  DebugKit.init(enabled: kDebugMode);
  runApp(const DebugKitOverlay(child: GoRouterExampleApp()));
}

class GoRouterExampleApp extends StatelessWidget {
  const GoRouterExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: _router);
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.goNamed(
            'profile',
            pathParameters: {'id': '42'},
            queryParameters: {'tab': 'activity'},
          ),
          child: const Text('Open profile'),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
    required this.tab,
  });

  final String userId;
  final String tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User $userId')),
      body: Center(child: Text('Selected tab: $tab')),
    );
  }
}
