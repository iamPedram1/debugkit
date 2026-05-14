# DebugKit Riverpod Adapter

A Riverpod provider observer adapter for [DebugKit](https://pub.dev/packages/debug_kit).

This adapter provides automatic logging of Riverpod provider failures and optional state updates directly into the DebugKit console.

## Features

- **Lifecycle Tracking**: Logs provider failures automatically.
- **Opt-In Update Logging**: Can log provider updates (disabled by default to prevent noise).
- **Targeted Observation**: Filter updates by a specific `Set` of `watchedProviders`.
- **Security First**: Sanitizes error logs, masks sensitive stringified objects, and aggressively limits stringification overhead.
- **Performance**: Zero overhead when DebugKit is disabled. Lightweight observer that will never throw or break state updates.

## Installation

Add `debug_kit_riverpod` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit_riverpod:
    git: # or path/pub version when available
```

## Setup

Initialize DebugKit and add the `DebugKitRiverpodObserver` to your `ProviderScope`:

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

## Configuration

By default, the observer logs ONLY failures. To log provider updates or enable value previews, pass a custom `DebugKitRiverpodConfig`:

```dart
final observer = DebugKitRiverpodObserver(
  config: DebugKitRiverpodConfig(
    logProviderUpdates: true, // Enables update logging
    watchedProviders: {'authProvider', 'userProvider'}, // Only log these
    includeValuePreview: true, // Calls .toString() on state updates
    maxValuePreviewLength: 300, // Truncates preview string
  ),
);
```

## What is Logged

- **Action**: `provider_failure`, `provider_update`.
- **Provider Information**: `provider_name`.
- **Value Preview**: Only if explicitly enabled.

## What is NOT Logged

- **Updates by Default**: State updates are ignored unless `logProviderUpdates` is `true`.
- **Full Values**: Raw models are not stringified unless `includeValuePreview` is `true`, and even then, they are heavily truncated and sanitized for obvious secrets.

## Limitations

- The value preview relies on `toString()`. If a custom model returns raw PII or secrets from `toString()` and it doesn't contain obvious keywords like `token` or `password`, the preview may log it. It is strongly recommended to leave `includeValuePreview: false` in production apps unless strictly debugging targeted `watchedProviders`.
- *Note: This package may display a pub.dev dry-run warning regarding its local path dependency on `debug_kit` while the core package remains unpublished.*

## License

MIT
