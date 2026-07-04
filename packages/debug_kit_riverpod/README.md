# DebugKit Riverpod Adapter

A Riverpod provider observer adapter for [DebugKit](https://pub.dev/packages/debug_kit).

Riverpod provider changes now appear in DebugKit's dedicated **State** tab by default, while the main **Logs** tab stays focused on app logs and errors.
When your provider state is shaped like JSON-friendly `Map` / `List` data, the State tab can show structured changed paths such as `profile.metadata.status` and inline diff snippets instead of only whole-object previews.

## Installation

Add both `debug_kit` and `debug_kit_riverpod` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit: ^0.11.1
  debug_kit_riverpod: ^0.5.1
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

This release line is for Riverpod 3 projects and supports `debug_kit ^0.11.0`.
DebugKit handles in-app logs, traces, and the structured generic State tab in core.

## Configuration

By default, provider changes are recorded into the State tab and provider failures still appear in Logs. Use `DebugKitRiverpodConfig` to control recording and log mirroring:

```dart
DebugKitRiverpodObserver(
  config: DebugKitRiverpodConfig(
    recordProviderAdds: true,
    recordProviderUpdates: true,
    recordProviderDisposals: true,
    recordProviderErrors: true,
    mirrorStateChangesToLogs: false, // Default: keep Logs tab quiet
    mirrorErrorsToLogs: true,        // Default: keep failures visible in Logs
    watchedProviders: {'authProvider', 'userProvider'},
    includeValuePreview: true,
    valueSerializer: (value) {
      if (value is MyModel) return value.toJson();
      return value;
    },
    maxValuePreviewLength: 500,
  ),
)
```

Provider names are taken from the explicit Riverpod name when available. If a provider is unnamed, the adapter falls back to a cleaned provider string or runtime type so the State tab still shows something useful instead of `UnnamedProvider` for normal cases.
The adapter now serializes `AsyncValue` wrappers, `toJson()` / `toMap()` models, iterables, and custom serializer output into structured diffs when possible. For arbitrary Dart objects, it keeps sanitized previews and falls back gracefully when a structured path diff is not available.

## What is Logged

- Provider additions, updates, disposals, and failures in the State tab
- Provider name, source, type, and event type metadata
- Structured diff paths for Map/List provider updates when available
- Structured values for `AsyncValue` wrappers, `toJson()` / `toMap()` models, iterables, and custom serializer output when available
- Sanitized value previews only when `includeValuePreview: true`
- Provider failures in Logs when `mirrorErrorsToLogs: true`

## What is NOT Logged

- Full state objects - previews are truncated and sanitized before storage
- Provider updates in the Logs tab by default
- Unfiltered lifecycle logs - when `watchedProviders` is set, only listed providers emit state events or mirrored logs

## Security & Sanitization

- Value previews are passed through the DebugKit core sanitizer before storage. Obvious secrets (tokens, passwords, API keys) in `toString()` output are masked.
- Previews are truncated at `maxValuePreviewLength` (default 500 chars).
- If `toString()` throws, the preview is replaced with `[Un-stringifyable Object]`.
- Preview sanitization honors the core `DebugKitSanitizerConfig` passed to `DebugKit.init()`.

> **Warning:** If a model's `toString()` returns raw PII that does not contain obvious secret keywords, it may appear in the preview. Keep `includeValuePreview: false` in production builds.

## Performance

Zero overhead when DebugKit is disabled (`enabled: false`). The observer wraps all logging in a try/catch and will never throw or interrupt state updates.

## Limitations

- Structured diffs are best for JSON-like `Map` / `List` data. Arbitrary Dart objects fall back to sanitized previews.
- Value preview sanitization relies on keyword matching. Custom models with non-standard secret field names are not automatically masked unless a custom serializer handles them.
- `includeValuePreview` should remain `false` in production builds.
- `valueSerializer` can be used to adapt app-specific models without leaking raw object strings.
- The State tab intentionally does not expose a source filter; source remains available in event details for future adapter support.
- This package line targets Riverpod 3 only. Riverpod 2 projects should stay on `debug_kit_riverpod ^0.2.3`.
- `logProviderUpdates` is still accepted as a deprecated alias for `recordProviderUpdates` so older code keeps compiling.

## Links

- [DebugKit Core](https://pub.dev/packages/debug_kit)
- [Example App](https://github.com/iamPedram1/debugkit/tree/main/examples/debug_kit_example)
- [Package Example](https://github.com/iamPedram1/debugkit/tree/main/packages/debug_kit_riverpod/example)

## Version compatibility

| Riverpod version | debug_kit_riverpod version |
| :--------------- | :------------------------- |
| Riverpod 2 | `^0.2.3` |
| Riverpod 3 | `^0.5.1` |

## Compatibility

| `debug_kit_riverpod` | `debug_kit` | `flutter_riverpod` |
|---|---|---|
| 0.5.1 | ^0.11.0 | 3.x |
| 0.5.0 | ^0.11.0 | 3.x |
| 0.2.3 | ^0.9.1 | 2.x |

## License

MIT
