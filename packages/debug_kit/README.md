# DebugKit

A mobile-first in-app DevTools/log console for Flutter apps.

DebugKit provides a searchable, filterable log viewer directly inside your app. It helps developers inspect logs, verify network calls (Phase 2), and debug state transitions without needing to attach a debugger or tail server logs.

> [!NOTE]
> This package is part of the [DebugKit Monorepo](https://github.com/iamPedram1/debug_kit).

## Screenshots

*(TODO: Add actual screenshots before pub.dev release)*

<div align="center">
  <img src="../../docs/assets/screenshots/overlay-button.png" width="200" alt="Overlay Button Placeholder">
  <img src="../../docs/assets/screenshots/console-all-logs.png" width="200" alt="Console Placeholder">
</div>

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
  debug_kit: ^0.2.1
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

### 4. Integration Packages

DebugKit relies on separate optional adapter packages to log automated events without bloating the core app:
- `debug_kit_dio`
- `debug_kit_go_router`
- `debug_kit_riverpod`

Check out the full [Example App](https://github.com/iamPedram1/debug_kit/tree/main/examples/debug_kit_example) in the repository to see them all working together!

## Sanitization & Security

DebugKit uses conservative best-effort sanitization to protect sensitive information before it reaches the in-memory store or exported logs:

- **Smart Masking**: Sensitive values (Tokens, API keys, Passwords) are partially masked based on their length.
  - Very short values (≤ 3 chars) are fully masked as `***`.
  - Longer values preserve a few start and end characters for context (e.g., `abc123secret` -> `abc******ret`).
- **Natural Language Protection**: DebugKit detects and masks secrets in plain text messages like `User password is: my_secret` or `token=my_token`.
- **Full Redaction**: High-risk secrets like private keys and mnemonic phrases are fully replaced with `[REDACTED]`.
- **Metadata Sanitization**: Metadata keys like `api_key` or `secret` are automatically sanitized.
- **Offline & Local**: DebugKit is strictly local. Logs are only stored in memory and never sent to any server.

> [!IMPORTANT]
> While DebugKit provides robust automatic sanitization, developers should still avoid intentionally logging raw production secrets.

## Roadmap
<truncated 4 lines>
- [x] Dio HTTP Interceptor (`debug_kit_dio`)
- [x] Navigation Observer (`debug_kit_go_router`)
- [x] Riverpod Observer (`debug_kit_riverpod`)
- [ ] AI Prompt Builder (Phase 3)
- [ ] Snapshots & Reproduction Sessions (Phase 4)

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for details on how to contribute to DebugKit.

## License

MIT
