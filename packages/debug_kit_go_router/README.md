# DebugKit GoRouter Adapter

A GoRouter navigation logging adapter for [DebugKit](https://pub.dev/packages/debug_kit).

This adapter provides automatic logging of GoRouter navigation events (push, pop, replace) directly into the DebugKit console.

## Features

- **Lifecycle Tracking**: Logs push, pop, and replace navigation events.
- **Security First**: Automatically sanitizes sensitive query parameters (e.g., tokens, emails) in routes.
- **Payload Protection**: Does NOT log route `extra` objects or stringify large route data to prevent PII leakage and performance degradation.
- **Performance**: Zero overhead when DebugKit is disabled. Lightweight observer that will never throw or break navigation.

## Installation

Add `debug_kit_go_router` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit_go_router:
    git: # or path/pub version when available
```

## Setup

See the [Example App](https://github.com/iamPedram1/debug_kit/tree/main/examples/debug_kit_example) for a complete working demonstration of all adapters combined.

Initialize DebugKit and add the `DebugKitGoRouterObserver` to your `GoRouter` configuration:

```dart
import 'package:go_router/go_router.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_go_router/debug_kit_go_router.dart';

void main() {
  DebugKit.init(enabled: true);

  final router = GoRouter(
    routes: [
      // your routes...
    ],
    observers: [
      DebugKitGoRouterObserver(),
    ],
  );

  runApp(MyApp(router: router));
}
```

## What is Logged

- **Action**: `push`, `pop`, `replace`.
- **Route Information**: `route_name`, `route_path`.
- **Previous Route**: `previous_route_name`, `previous_route_path`.

## What is NOT Logged

- **Route `extra`**: Extra objects passed during navigation are explicitly ignored.
- **Sensitive Query Params**: Parameters like `token`, `password`, `email`, and `api_key` are masked in the route path.

## Limitations

- The observer only captures events triggered through the Flutter `Navigator` API, which GoRouter delegates to. Some advanced GoRouter-specific internal state changes might not be perfectly mapped, but standard push/pop/replace flows are fully supported.
- *Note: This package may display a pub.dev dry-run warning regarding its local path dependency on `debug_kit` while the core package remains unpublished.*

## License

MIT
