# DebugKit Riverpod Adapter

A Riverpod provider observer adapter for [DebugKit](https://pub.dev/packages/debug_kit).

Automatically logs Riverpod provider failures and optionally state updates into the DebugKit in-app console with sanitization.

## Installation

Add both `debug_kit` and `debug_kit_riverpod` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit: ^0.9.1
  debug_kit_riverpod: ^0.3.0
  flutter_riverpod: ^3.0.0
```

## Setup

Initialize DebugKit and add `DebugKitRiverpodObserver` to your `ProviderScope`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_riverpod/debug_kit_riverpod.dart';

void main() {
  DebugKit.init(enabled: true);

  runApp(
    ProviderScope(
      observers: [
        DebugKitRiverpodObserver(),
      ],
      child: const MyApp(),
    ),
  );
}
```

This release line is for Riverpod 3 projects and supports `debug_kit ^0.9.1`.
DebugKit handles in-app logs and sanitized console mirroring in core.

## Configuration

By default, provider failures are logged. Use `DebugKitRiverpodConfig` to enable compact provider lifecycle logging or value previews:

```dart
DebugKitRiverpodObserver(
  config: DebugKitRiverpodConfig(
    logProviderUpdates: true,       // Log state updates (default: false)
    watchedProviders: {'authProvider', 'userProvider'}, // Scope to specific providers
    includeValuePreview: true,      // Call .toString() on new state (default: false)
    maxValuePreviewLength: 300,     // Truncate preview at this length
  ),
)
```

## What is Logged

- Provider name and event type (`provider_failure`, `provider_add`, `provider_update`, `provider_dispose`)
- Error message and stack trace on failures
- Sanitized value preview - only when `includeValuePreview: true`

## What is NOT Logged

- Full state objects - raw models are never stringified unless `includeValuePreview: true`
- Unfiltered lifecycle logs - when `watchedProviders` is set, only listed providers emit add/update/dispose logs (failures are always logged regardless)

## Security & Sanitization

- Value previews are passed through the DebugKit core sanitizer before storage. Obvious secrets (tokens, passwords, API keys) in `toString()` output are masked.
- Previews are truncated at `maxValuePreviewLength` (default 300 chars).
- If `toString()` throws, the preview is replaced with `[Un-stringifyable Object]`.

> **Warning:** If a model's `toString()` returns raw PII that does not contain obvious secret keywords, it may appear in the preview. Keep `includeValuePreview: false` in production builds.

## Performance

Zero overhead when DebugKit is disabled (`enabled: false`). The observer wraps all logging in a try/catch and will never throw or interrupt state updates.

## Limitations

- Value preview sanitization relies on keyword matching. Custom models with non-standard secret field names are not automatically masked.
- `includeValuePreview` should remain `false` in production builds.
- This package line targets Riverpod 3 only. Riverpod 2 projects should stay on `debug_kit_riverpod ^0.2.3`.

## Links

- [DebugKit Core](https://pub.dev/packages/debug_kit)
- [Example App](https://github.com/iamPedram1/debugkit/tree/main/examples/debug_kit_example)

## Version compatibility

| Riverpod version | debug_kit_riverpod version |
| :--------------- | :------------------------- |
| Riverpod 2 | `^0.2.3` |
| Riverpod 3 | `^0.3.0` |

## Compatibility

| `debug_kit_riverpod` | `debug_kit` | `flutter_riverpod` |
|---|---|---|
| 0.3.0 | ^0.9.1 | 3.x |
| 0.2.3 | ^0.9.1 | 2.x |

## License

MIT
