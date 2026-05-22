# DebugKit Dio Adapter

A Dio network logging adapter for [DebugKit](https://pub.dev/packages/debug_kit).

Automatically logs Dio network requests, responses, and errors into the DebugKit in-app console with sanitization and lifecycle tracking.

## Installation

Add both `debug_kit` and `debug_kit_dio` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit: ^0.2.2
  debug_kit_dio: ^0.1.0
```

## Setup

Initialize DebugKit and pass a `DebugKitDioAdapter` in the `adapters` list:

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

Alternatively, add the interceptor directly to an existing Dio instance:

```dart
dio.interceptors.add(DebugKitDioInterceptor(DebugKit.controller));
```

## What is Logged

- HTTP method and sanitized URL (query params masked)
- Response status code and request duration
- Sanitized request headers
- Sanitized response headers
- Error type and message on failure
- Cancelled request status

## What is NOT Logged

- Request bodies — never logged to prevent PII leakage
- Response bodies — never logged by default
- Binary or multipart payloads — always ignored

## Security & Sanitization

- URLs: Sensitive query parameters (e.g., `api_key`, `token`, `password`) are masked using smart length-aware masking.
- Headers: Sensitive headers like `Authorization`, `Cookie`, and `X-API-Key` are automatically masked.
- Bodies: Request and response bodies are never captured.

## Performance

Zero overhead when DebugKit is disabled (`enabled: false`). The interceptor checks the enabled flag synchronously before any work and never blocks the Dio handler chain.

## Limitations

- Request and response bodies are not logged. Opt-in body logging is not yet supported.
- Binary and multipart payloads are always ignored.

## Links

- [DebugKit Core](https://pub.dev/packages/debug_kit)
- [Example App](https://github.com/iamPedram1/debug_kit/tree/main/examples/debug_kit_example)

## License

MIT
