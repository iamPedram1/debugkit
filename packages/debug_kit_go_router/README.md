# DebugKit GoRouter Adapter

A GoRouter navigation logging adapter for [DebugKit](https://pub.dev/packages/debug_kit).

Automatically logs GoRouter navigation events (push, pop, replace, remove) into the DebugKit in-app console with query parameter sanitization.

## Installation

Add both `debug_kit` and `debug_kit_go_router` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit: ^0.10.0
  debug_kit_go_router: ^0.3.0
```

## Setup

Initialize DebugKit and add `DebugKitGoRouterObserver` to your `GoRouter` configuration:

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

- Navigation action: `push`, `pop`, `replace`, `remove`
- Sanitized route path (query params masked)
- Previous route path where applicable

## What is NOT Logged

- Route `extra` objects — explicitly ignored to prevent PII leakage and avoid stringifying large payloads
- Sensitive query parameters — values for keys like `token`, `password`, `api_key` are masked before logging

## Security & Sanitization

Route paths are sanitized using the same smart masking engine as the DebugKit core. Sensitive query parameter values are masked based on their length before being stored or displayed.

## Performance

Zero overhead when DebugKit is disabled (`enabled: false`). The observer wraps all logging in a try/catch and will never throw or interrupt navigation.

## Limitations

- The observer captures events via the Flutter `Navigator` API, which GoRouter delegates to. Standard push/pop/replace/remove flows are fully supported.
- Route `extra` payloads are never logged regardless of content.

## Links

- [DebugKit Core](https://pub.dev/packages/debug_kit)
- [Example App](https://github.com/iamPedram1/debugkit/tree/main/examples/debug_kit_example)

## Compatibility

| `debug_kit_go_router` | `debug_kit` |
|---|---|
| 0.3.0 | ^0.10.0 |

## License

MIT
