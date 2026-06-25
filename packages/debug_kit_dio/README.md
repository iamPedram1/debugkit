# DebugKit Dio Adapter

A Dio network logging adapter for [DebugKit](https://pub.dev/packages/debug_kit).

Automatically logs Dio network requests, responses, and errors into the DebugKit in-app console with sanitization and lifecycle tracking.

## Installation

Add both `debug_kit` and `debug_kit_dio` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit: ^0.9.1
  debug_kit_dio: ^0.4.1
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

- HTTP method plus sanitized URL, host, path, and query metadata
- Request and response phase updates for the Network Inspector
- Response status code, duration, and error metadata
- Backend correlation IDs from allowlisted response headers only
- Cancelled request status
- Optional sanitized request/response header previews when enabled
- Optional request/response body previews when explicitly enabled

The adapter also feeds the DebugKit Network Inspector with the request list,
summary strip, detail tabs, and waterfall timing.

## What is NOT Logged

- Request bodies — never logged by default
- Response bodies — never logged by default
- Binary or multipart payloads — always ignored
- Authorization, Cookie, Set-Cookie, or arbitrary response headers — not stored by default
- Raw backend headers outside the allowlist below

## Security & Sanitization

- URLs: Sensitive query parameters (e.g., `api_key`, `token`, `password`) are masked using smart length-aware masking.
- Response headers: Only the allowlisted backend correlation headers below are captured, and values are sanitized and truncated to 64 characters.
- Headers: request header previews are opt-in and sanitized; response header previews use a safe allowlist only.
- Bodies: request and response body previews are opt-in and disabled by default.

## Preview Config

Use `DebugKitDioConfig` when you want safe previews in the Network Inspector:

```dart
DebugKit.init(
  adapters: [
    DebugKitDioAdapter(
      dio,
      config: const DebugKitDioConfig(
        captureRequestHeaders: true,
        captureResponseHeaders: true,
        captureRequestBody: false,
        captureResponseBody: false,
      ),
    ),
  ],
);
```

Defaults stay safe:

- `captureRequestHeaders: false`
- `captureResponseHeaders: false`
- `captureRequestBody: false`
- `captureResponseBody: false`
- `maxBodyPreviewChars: 1000`
- `maxCaptureBytes: 65536`

### Allowlisted backend correlation headers

- `x-request-id` and `request-id` → `backendRequestId`
- `x-correlation-id` → `backendCorrelationId`
- `x-trace-id` and `trace-id` → `backendTraceId`

## Performance

Zero overhead when DebugKit is disabled (`enabled: false`). The interceptor checks the enabled flag synchronously before any work and never blocks the Dio handler chain.

## Limitations

- Request and response bodies are not logged. Opt-in body logging is not yet supported.
- Binary and multipart payloads are always ignored.

## Links

- [DebugKit Core](https://pub.dev/packages/debug_kit)
- [Example App](https://github.com/iamPedram1/debugkit/tree/main/examples/debug_kit_example)

## Compatibility

| `debug_kit_dio` | `debug_kit` |
|---|---|
| 0.4.1 | ^0.9.1 |

## License

MIT
