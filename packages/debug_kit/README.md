# DebugKit

A mobile-first in-app DevTools/log console for Flutter apps.

DebugKit provides a searchable, filterable log viewer directly inside your app. It helps developers inspect logs, verify network calls (Phase 2), and debug state transitions without needing to attach a debugger or tail server logs.

> [!NOTE]
> This package is part of the [DebugKit Monorepo](https://github.com/iamPedram1/debug_kit).

## Features

- **Mobile-First UI**: A floating, draggable button that works on real devices.
- **Search & Filter**: Quickly find logs by level (Debug, Info, Warning, Error), source, or text.
- **Security First**: Automatic sanitization and masking of sensitive data (Tokens, API Keys, Passwords, Private Keys).
- **Performance Hardened**: Bounded in-memory log store (default 300) with zero overhead when disabled.
- **Export Anywhere**: Copy logs to clipboard or share them as a file.
- **Manual Logging API**: Easy-to-use API for application-level logs and user actions.

## Installation

Add `debug_kit` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit:
    git: # or path/pub version when available
```

## 5-Minute Setup

### 1. Initialize DebugKit

Call `DebugKit.init()` in your `main()` function:

```dart
void main() {
  DebugKit.init(
    enabled: true, // Typically kDebugMode
    maxLogs: 300,
  );

  runApp(
    const DebugKitOverlay(
      child: MyApp(),
    ),
  );
}
```

### 2. Wrap your App

Wrap your root widget with `DebugKitOverlay` to enable the floating debug button.

### 3. Start Logging

```dart
DebugKit.log.info('App started');
DebugKit.log.debug('Config loaded', metadata: {'env': 'prod'});
DebugKit.log.warning('Slow response from server');
DebugKit.log.error('Auth failed', error: e, stackTrace: s);
```

## Sanitization Guarantees

DebugKit automatically masks sensitive information before it even reaches the log store:

- **Masked**: Bearer tokens, API keys, Cookies, Passwords (e.g., `eyJh***9xQ`).
- **Redacted**: Ethereum private keys and BIP-39 mnemonic phrases are fully replaced with `[REDACTED]`.

## Roadmap

- [ ] Dio HTTP Interceptor (Phase 2)
- [ ] Riverpod / Bloc Observers (Phase 2)
- [ ] Navigation Observer (Phase 2)
- [ ] AI Prompt Builder (Phase 2)
- [ ] Snapshots & Reproduction Sessions

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for details on how to contribute to DebugKit.

## License

MIT
