# DebugKit

A mobile-first in-app DevTools/log console for Flutter apps.

DebugKit provides a searchable, filterable log viewer directly inside your app. It helps developers inspect logs, verify network calls, and debug state transitions without needing to attach a debugger or tail server logs.

> [!NOTE]
> This package is part of the [DebugKit Monorepo](https://github.com/iamPedram1/debug_kit).

## Features

- **Mobile-First UI**: A floating, draggable button that works on real devices.
- **Search & Filter**: Quickly find logs by level (Debug, Info, Warning, Error), source, or text.
- **Security First**: Automatic sanitization and smart masking of sensitive data (Tokens, API Keys, Passwords, Private Keys, Mnemonics).
- **Performance Hardened**: Bounded in-memory log store (default 300) with zero overhead when disabled.
- **Export Anywhere**: Copy logs to clipboard or share them as a file.
- **Manual Logging API**: Easy-to-use API for application-level logs and user actions.

## Installation

Add `debug_kit` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit: ^0.2.2
```

## 5-Minute Setup

### 1. Initialize DebugKit

Call `DebugKit.init()` in your `main()` function before `runApp`:

```dart
void main() {
  DebugKit.init(
    enabled: true, // Use kDebugMode in production apps
    maxLogs: 300,
  );
  runApp(const MyApp());
}
```

### 2. Add the Overlay

Wrap your app with `DebugKitOverlay`. For apps using a router (GoRouter, Navigator 2), use `MaterialApp.builder` so the overlay sits above all routes:

```dart
MaterialApp.router(
  routerConfig: _router,
  builder: (context, child) => DebugKitOverlay(child: child!),
)
```

For simple apps without a router:

```dart
runApp(const DebugKitOverlay(child: MyApp()));
```

### 3. Start Logging

```dart
DebugKit.log.info('App started');
DebugKit.log.debug('Config loaded', metadata: {'env': 'prod'});
DebugKit.log.warning('Slow response from server');
DebugKit.log.error('Auth failed', error: e, stackTrace: s);
DebugKit.log.userAction('Tapped checkout button');
```

### 4. Clear Logs

```dart
DebugKit.clearLogs(); // Clears all in-memory logs
```

### 5. Disabled Mode

Pass `enabled: false` to completely disable DebugKit. No logs are stored, no overlay is shown, and there is zero runtime overhead:

```dart
DebugKit.init(enabled: kDebugMode);
```

Check the current state at any time:

```dart
if (DebugKit.isEnabled) { ... }
```

### 6. Integration Packages

DebugKit relies on separate optional adapter packages to log automated events without bloating the core:

- [`debug_kit_dio`](https://pub.dev/packages/debug_kit_dio) — Dio HTTP interceptor
- [`debug_kit_go_router`](https://pub.dev/packages/debug_kit_go_router) — GoRouter navigation observer
- [`debug_kit_riverpod`](https://pub.dev/packages/debug_kit_riverpod) — Riverpod state observer

Check out the full [Example App](https://github.com/iamPedram1/debug_kit/tree/main/examples/debug_kit_example) to see them all working together.

## Sanitization & Security

DebugKit uses conservative best-effort sanitization to protect sensitive information before it reaches the in-memory store or exported logs:

- **Smart Masking**: Sensitive values (Tokens, API keys, Passwords) are partially masked based on their length.
  - Very short values (≤ 3 chars) are fully masked as `***`.
  - Longer values preserve a few start and end characters for context (e.g., `abc123secret` → `ab********et`).
- **Natural Language Protection**: Detects and masks secrets in plain text like `User password is: my_secret` or `token=my_token`.
- **Full Redaction**: High-risk secrets like private keys (64-char hex) and mnemonic phrases are fully replaced with `[REDACTED PRIVATE KEY]` / `[REDACTED MNEMONIC]`.
- **Metadata Sanitization**: Metadata keys like `api_key` or `secret` are automatically sanitized.
- **Offline & Local**: DebugKit is strictly local. Logs are only stored in memory and never sent to any server.

> [!IMPORTANT]
> While DebugKit provides robust automatic sanitization, developers should still avoid intentionally logging raw production secrets.

## Roadmap

- [x] Core logging engine and console UI
- [x] Automatic sanitization and smart masking
- [x] Dio HTTP Interceptor (`debug_kit_dio`)
- [x] Navigation Observer (`debug_kit_go_router`)
- [x] Riverpod Observer (`debug_kit_riverpod`)
- [ ] AI Prompt Builder (Phase 3)
- [ ] Snapshots & Reproduction Sessions (Phase 4)

## Contributing

See [CONTRIBUTING.md](https://github.com/iamPedram1/debug_kit/blob/main/CONTRIBUTING.md) for details.

## License

MIT
