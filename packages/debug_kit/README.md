# DebugKit

A mobile-first in-app DevTools/log console for Flutter apps.

DebugKit provides a searchable, filterable log viewer directly inside your app. It helps developers inspect logs, verify network calls, and debug state transitions without needing to attach a debugger or tail server logs.

> [!NOTE]
> This package is part of the [DebugKit Monorepo](https://github.com/iamPedram1/debugkit).

## Features

- **Mobile-First UI**: A floating, draggable button that works on real devices.
- **Search & Filter**: Quickly find logs by level (Debug, Info, Warning, Error), source, or text.
- **Repeated Log Grouping**: Consecutive identical logs are collapsed into a single row with a `×N` repeat badge — like Chrome DevTools console.
- **Error Digest**: Groups repeated and related errors into a digest so you can immediately see what failed, how often, and where — without scrolling through raw logs.
- **Network Summary**: A generic network intelligence tab that summarizes request volume, status families, slow endpoints, and backend correlation IDs when `debug_kit_dio` is installed.
- **Security First**: Automatic sanitization and smart masking of sensitive data (Tokens, API Keys, Passwords, Private Keys, Mnemonics).
- **Performance Hardened**: Bounded in-memory log store (default 300) with zero overhead when disabled.
- **Export Anywhere**: Copy logs to clipboard or share them as a sanitized `.txt` file via the platform share sheet. No request/response bodies are included by default.
- **Trace System**: Named async traces with timeline, health analysis, and correlation to logs, network, navigation, and state events.
- **Manual Logging API**: Easy-to-use API for application-level logs and user actions.

## Installation

Add `debug_kit` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit: ^0.6.0
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

- [`debug_kit_dio`](https://pub.dev/packages/debug_kit_dio) — Dio HTTP interceptor that feeds Network Summary
- [`debug_kit_go_router`](https://pub.dev/packages/debug_kit_go_router) — GoRouter navigation observer
- [`debug_kit_riverpod`](https://pub.dev/packages/debug_kit_riverpod) — Riverpod state observer

Check out the full [Example App](https://github.com/iamPedram1/debugkit/tree/main/examples/debug_kit_example) to see them all working together.

## Repeated Log Grouping

When the same log is emitted repeatedly in a row, DebugKit collapses the duplicates into a single entry with a `×N` badge — the same behavior as the Chrome DevTools console.

```dart
// These three calls produce one row in the console: "Retrying request  ×3"
DebugKit.log.warning('Retrying request');
DebugKit.log.warning('Retrying request');
DebugKit.log.warning('Retrying request');
```

Grouping is **consecutive-only**: if a different log appears between two identical messages they remain separate rows. This keeps the behavior predictable.

```
A  →  A ×3
A      A ×3
A      B
B      A
A
```

### Disabling grouping

```dart
DebugKit.init(
  enabled: true,
  groupRepeatedLogs: false, // store every emission independently
);
```

### What gets grouped

Two entries are considered equivalent when their **fingerprint** matches. The fingerprint includes:

| Included | Excluded |
|----------|----------|
| `level` | `id` |
| `source` | `timestamp` / `lastSeenAt` |
| `message` | `repeatCount` |
| `error` | `duration_ms` metadata |
| First stack trace line | `response_headers` metadata |
| `traceId` | |
| Stable metadata key=value pairs | |

**Network logs (entries with a `requestId`) are never grouped**, regardless of fingerprint. The Dio adapter updates log entries in-place by `requestId` — merging two concurrent identical network requests would silently lose one of their updates. Each network transaction always occupies its own row.

### In the UI

- Collapsed tile: `×N` badge in the header row.
- Expanded tile: **Repeat**, **First seen**, and **Last seen** detail blocks.
- Long-press copy: includes `×N` prefix when grouped.

### In exports

Grouped entries export as **one block** — never expanded into N lines:

```
[WRN][APP] 14:21:02 ×12
Message: Retrying request
First seen: 2026-06-16 14:21:02.000
Last seen : 2026-06-16 14:21:09.000
```

### Security

The fingerprint is computed on already-sanitized values — raw secrets never reach the comparison logic. Grouping never merges logs from different traces (`traceId` is included in the fingerprint).

## Exporting Logs

The DebugKit console provides two export actions in the AppBar:

- **Copy all** — copies all logs to the clipboard as formatted text.
- **Export logs** / **Export filtered logs** — writes a sanitized `.txt` file to the device's temporary directory and opens the platform share sheet. The label changes to *Export filtered logs* when search or level/source filters are active, exporting only the currently visible entries.

Exported file name format: `debugkit-logs-YYYYMMDD-HHMMSS.txt`

> [!IMPORTANT]
> Exported logs contain only the already-sanitized values stored in memory. Raw tokens, passwords, API keys, private keys, cookies, and mnemonic phrases are never written to the export file. Request and response bodies are not captured or exported by default.
> When network transactions are present, exports also include a sanitized Network Summary section. It is derived from already-stored values only and never includes request/response bodies or arbitrary headers.

If the share sheet fails, DebugKit automatically falls back to copying the formatted text to the clipboard and shows a SnackBar notification.


DebugKit uses conservative best-effort sanitization to protect sensitive information before it reaches the in-memory store or exported logs:

- **Smart Masking**: Sensitive values (Tokens, API keys, Passwords) are partially masked based on their length.
  - Very short values (≤ 3 chars) are fully masked as `***`.
  - Longer values preserve a few start and end characters for context (e.g., `abc123secret` → `ab********et`).
- **Natural Language Protection**: Detects and masks secrets in plain text like `User password is: my_secret` or `token=my_token`.
- **Full Redaction**: High-risk secrets like private keys (64-char hex) and explicitly labeled mnemonic phrases are fully replaced with `[REDACTED PRIVATE KEY]` / `[REDACTED MNEMONIC]`.
- **Metadata Sanitization**: Metadata keys like `api_key` or `secret` are automatically sanitized.
- **Offline & Local**: DebugKit is strictly local. Logs are only stored in memory and never sent to any server.

> [!IMPORTANT]
> While DebugKit provides robust automatic sanitization, developers should still avoid intentionally logging raw production secrets.

## Error Digest

DebugKit groups repeated and related errors into a digest so you can quickly see
what failed most often and where it happened.

The digest is built on demand from the current log and trace stores. It is
accessible via the new **Errors** tab in the console UI, via the programmatic API,
and in the `.txt` export.

### What the digest detects

- Logs with `level == error`
- Warning-level logs that carry an `error` field
- Failed `DebugTrace` instances (when the trace system is in use)
- Dio failed requests (when `debug_kit_dio` is installed)
- Riverpod provider failures (when `debug_kit_riverpod` is installed)

### Fingerprint strategy

Two errors are considered the same class of failure and merged into one digest
entry when their fingerprint matches:

| Error source | Fingerprint key |
|---|---|
| Dio network error | `method + path + status code` |
| Riverpod provider failure | `provider_name + error type prefix` |
| App / trace error | `error type prefix + normalized message + first useful stack frame` |

Different exception types, different HTTP status codes, and different provider
names always stay as separate entries.

### Programmatic access

```dart
// Build the digest on demand
final digest = DebugKit.errors.buildDigest();

print('Unique errors  : ${digest.uniqueErrors}');
print('Total occurred : ${digest.totalErrors}');
print('Failed requests: ${digest.failedNetworkCount}');
print('Failed traces  : ${digest.failedTraceCount}');

for (final entry in digest.entries) {
  print('${entry.title}  ×${entry.count}  [${entry.severity.label}]');
  if (entry.relatedTraceNames.isNotEmpty) {
    print('  Traces: ${entry.relatedTraceNames.join(', ')}');
  }
}
```

> **Do not call `buildDigest()` on every frame.** Compute it once per user
> interaction or store change, then cache the result.

### Count behavior with repeated logs

`DebugLogEntry.repeatCount` contributes to the digest entry count. A log emitted
5 times and stored as a single grouped entry (with `repeatCount = 5`) will produce
a digest entry with `count = 5`, not `count = 1`.

### In the console UI

The **Errors** tab shows:

- A summary bar with unique error count, total occurrences, failed network requests,
  and failed traces.
- A list of error entries sorted by severity → frequency → recency.
- Each tile: severity badge, title, `×N` count badge, source chip, last-seen time,
  first useful stack frame, and related context chips (traces, providers, requests).
- Tap any entry to open the detail screen: full error, stack trace, related context,
  and health hints. Copy summary to clipboard.

### In exports

The `.txt` export includes a `DebugKit Error Digest` section after the Traces
section:

```
DebugKit Error Digest
Generated : 2026-06-17 10:05:00
Total     : 12 occurrences
Unique    : 3 error classes
Network   : 2 failed request(s)
============================================================

[ERROR][RVP] Provider failed: authProvider ×8
  Severity   : ERROR
  Source     : RVP
  Count      : ×8
  First seen : 2026-06-17 10:00:00
  Last seen  : 2026-06-17 10:04:58
  Error      : Exception: invalid token
  Traces     : login_flow, refresh_profile
  Hint       : Provider: authProvider
  Hint       : Occurred 8 times
------------------------------------------------------------
```

### Sanitization guarantees

- All digest fields contain only already-sanitized values from the log store.
- No request/response bodies are included.
- No route `extra` objects are included.
- No provider state objects are included.
- Fingerprinting operates on sanitized values — raw secrets never reach the
  comparison logic.

### Limitations

- The digest is a session-only, in-memory snapshot. It is not persisted across
  app restarts.
- The digest only covers errors observed since the last `DebugKit.init()` call
  or `DebugKit.clearLogs()`.
- Call-site location is not extracted for digest entries (only for raw log entries).
- Global Flutter error capture (`FlutterError.onError`) is not automatically hooked
  — see the roadmap.

## Network Summary

The **Network** tab gives you a quick, in-app overview of HTTP behavior when
`debug_kit_dio` is installed.

It summarizes:

- Total, completed, failed, pending, and slow requests
- Status breakdown: 2xx, 3xx, 4xx, 5xx, and unknown
- Average, max, and min duration plus the configured slow threshold
- Top failing endpoints and slowest endpoints
- Backend correlation IDs when the adapter captures them from response headers

The summary is built on demand from the bounded in-memory log store and is safe
to export or copy because it uses only already-sanitized values.

Set `slowRequestThresholdMs` in `DebugKit.init()` if you want a threshold
other than the 500ms default.

```dart
final summary = DebugKit.controller.buildNetworkSummary();
print('Requests: ${summary.totalRequests}');
print('Slow: ${summary.slowRequests}');
```

If no Dio adapter is installed yet, the Network tab shows an empty state that
explains how to enable it.

## Roadmap

- [x] Core logging engine and console UI
- [x] Automatic sanitization and smart masking
- [x] Dio HTTP Interceptor (`debug_kit_dio`)
- [x] Navigation Observer (`debug_kit_go_router`)
- [x] Riverpod Observer (`debug_kit_riverpod`)
- [x] Repeated log grouping (Chrome DevTools-style `×N` badge)
- [x] Trace system with timeline, health analysis, and adapter correlation
- [x] Error Digest — grouped, de-duplicated error intelligence
- [ ] Global Flutter error capture (opt-in `FlutterError.onError` hook)
- [ ] AI Prompt Builder (Phase 3)
- [ ] Snapshots & Reproduction Sessions (Phase 4)

## Contributing

See [CONTRIBUTING.md](https://github.com/iamPedram1/debugkit/blob/main/CONTRIBUTING.md) for details.

## License

MIT
