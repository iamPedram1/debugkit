# DebugKit Dio Adapter

A Dio network logging adapter for [DebugKit](https://pub.dev/packages/debug_kit).

This adapter provides automatic logging of Dio network transactions directly into the DebugKit console.

## Features

- **Automatic Lifecycle Tracking**: Logs requests as "pending" and updates them with status codes and durations upon completion or error.
- **Security First**: Automatically sanitizes URLs, query parameters, and headers (e.g., Authorization, Cookie).
- **Body Protection**: Does NOT log request or response bodies by default to prevent accidental leakage of PII or large payloads.
- **Performance**: Zero overhead when DebugKit is disabled. Synchronous, lightweight logging that never blocks the Dio handler flow.

## Installation

Add `debug_kit_dio` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit_dio:
    git: # or path/pub version when available
```

## Setup

See the [Example App](https://github.com/iamPedram1/debug_kit/tree/main/examples/debug_kit_example) for a complete working demonstration of all adapters combined.

Initialize DebugKit and provide the `DebugKitDioAdapter`:

```dart
import 'package:dio/dio.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_dio/debug_kit_dio.dart';

void main() {
  final dio = Dio();

  DebugKit.init(
    enabled: true,
    adapters: [
      DebugKitDioAdapter(dio),
    ],
  );

  runApp(const MyApp());
}
```

Alternatively, you can add the interceptor manually:

```dart
dio.interceptors.add(DebugKitDioInterceptor(DebugKit.controller));
```

## Security & Sanitization

DebugKit Dio Adapter takes security seriously:

- **URLs**: Common sensitive query parameters (e.g., `api_key`, `token`, `password`) are masked with `***`.
- **Headers**: Sensitive headers like `Authorization`, `Cookie`, and `X-API-Key` are automatically masked.
- **Bodies**: Request and response bodies are NOT logged by default. Binary and multipart payloads are always ignored.

## Roadmap

- [ ] Optional opt-in for body logging (Phase 2B)
- [ ] CURL command export (Phase 2B)
- [ ] Network inspector UI in DebugKit (Phase 3)

## License

MIT
