# DebugKit

A mobile-first in-app DevTools/log console for Flutter apps.

DebugKit provides a searchable, filterable log viewer directly inside your app. It helps developers inspect logs, verify network calls, and debug state transitions without needing to attach a debugger or tail server logs.

> [!NOTE]
> This package is part of the [DebugKit Monorepo](https://github.com/iamPedram1/debugkit).

## Features

- **Mobile-First UI**: A floating, draggable button that works on real devices.
- **Search & Filter**: Quickly find logs by level (Debug, Info, Warning, Error), source, or text.
- **Repeated Log Grouping**: Consecutive identical logs are collapsed into a single row with a `×N` repeat badge — like Chrome DevTools console.
- **Console Mirroring**: Sanitized logs print to the Flutter / IDE console by default using configurable `tiny`, `short`, `dev`, or `detailed` formats.
- **Error Digest**: Groups repeated and related errors into a digest so you can immediately see what failed, how often, and where — without scrolling through raw logs.
- **Network Inspector**: A Chrome-inspired mobile-first network tab with compact, scroll-aware controls, a shared top timeline overview, color-coded method badges, tabbed detail (Overview / Headers / Request / Response / Error / Timeline), filtering, sorting, a lightweight request timeline / mini waterfall, request selection highlighting, and a slim summary strip — when `debug_kit_dio` is installed.
- **State Tab**: A dedicated, state-management-agnostic timeline for provider and state changes so Riverpod, Bloc, Provider, and future adapters stay out of the main Logs tab. Structured Map/List updates can show inline changed-field previews in the list, with full details available on tap.
- **Security First**: Automatic sanitization and smart masking of sensitive data (Tokens, API Keys, Passwords, PEM Private Keys, Mnemonics).
- **Performance Hardened**: Bounded in-memory log store (default 300) with zero overhead when disabled.
- **Export Anywhere**: Copy logs to clipboard or share them as a sanitized `.txt` file via the platform share sheet. No request/response bodies are included by default.
- **Trace System**: Named async traces with timeline, health analysis, and correlation to logs, network, navigation, and state events.
- **Manual Logging API**: Easy-to-use API for application-level logs and user actions.

The Network Inspector uses a shared, app-level timeline based on request start time and duration across the currently visible requests. Pending requests extend to "now" while they are still in flight. It does not expose Chrome-level DNS/TCP/TLS/TTFB phases unless a future adapter provides that data.

The Network tab keeps the request list as the primary focus. Search and filter controls auto-hide as you scroll the list down, active filters stay visible in compact mode, and the shared timeline overview can be shown or hidden without losing range or selection state.

DebugKit also mirrors sanitized logs to the terminal by default, so the same events stay visible in both the in-app console and the Flutter / IDE output. Terminal output is colorized by default, uses compact `·` separators for scannable rows, and keeps ANSI codes out of the in-app UI and exports. Compact console formats only shorten DebugKit-generated technical summaries such as Dio and GoRouter logs; manual app logs always keep their full sanitized message.

The Logs tab may visually wrap or collapse long entries for readability, but the detail view, copy action, and export pipeline all use the full sanitized message.

## Installation

Add `debug_kit` to your `pubspec.yaml`:

```yaml
dependencies:
  debug_kit: ^0.10.1
```

## 5-Minute Setup

### 1. Initialize DebugKit

Call `DebugKit.init()` in your `main()` function before `runApp`:

```dart
void main() {
DebugKit.init(
  enabled: true, // Use kDebugMode in production apps
  maxLogs: 300,
  printToConsole: true,
  consolePrintFormat: DebugConsolePrintFormat.dev,
  sanitizer: const DebugKitSanitizerConfig(),
);
  runApp(const MyApp());
}
```

Console mirroring is enabled by default. You can turn it off entirely with `printToConsole: false`, or keep it enabled and switch formats:

```dart
DebugKit.init(
  enabled: true,
  printToConsole: true,
  consolePrintFormat: DebugConsolePrintFormat.short,
  colorizeConsoleOutput: true,
  printNetworkLogs: true,
  printRouterLogs: true,
  printRiverpodLogs: true,
);
```

Supported console formats:

- `tiny` - absolute minimum signal, segmented with `·` separators
- `short` - timestamped one-line output for chronological scanning
- `dev` - default compact developer-friendly output with status symbols
- `detailed` - multi-line structured output for diagnostics and copy/paste reports

These formats control the presentation of DebugKit-generated summaries. They do not truncate developer-authored logs from `DebugKit.log.*()` or forwarded app logger messages.

Colorization is terminal-only and enabled by default. Disable it with `colorizeConsoleOutput: false` if you prefer plain text.

DebugKit keeps sanitization enabled by default. You can disable one category at a time when you need more signal during trusted debugging sessions:

```dart
DebugKit.init(
  enabled: true,
  sanitizer: const DebugKitSanitizerConfig(
    redactPrivateKeys: false,
  ),
);
```

You can also disable every sanitizer rule, but this is only safe in trusted local development:

```dart
DebugKit.init(
  enabled: true,
  sanitizer: const DebugKitSanitizerConfig(
    dangerouslyDisableSanitizer: true,
  ),
);
```

Only use `dangerouslyDisableSanitizer` in trusted local development sessions. Never enable it in production, QA builds shared with external testers, or logs that may be exported.

Format guide:

| Format | Purpose | Shape |
|---|---|---|
| `tiny` | Noisy terminals | One line, minimal signal |
| `short` | Chronological scanning | `HH:mm:ss` + compact source label |
| `dev` | Everyday development | Symbol-led, status-aware, scan-friendly |
| `detailed` | Diagnostics / support | Multiline structured report |

Examples:

```text
tiny: INFO · App started
short: 10:14:09 · INFO · app · App started
dev:   ℹ app · App started
detailed: [DebugKit][2026-06-23T10:14:09.613][INFO][APP]
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

If your app already has its own debug sheet or menu, you can keep the DebugKit overlay mounted but hide the built-in floating button:

```dart
void main() {
  DebugKit.init(
    enabled: true,
    disableDefaultOverlayButton: true,
  );

  runApp(
    DebugKitOverlay(
      child: MyApp(),
    ),
  );
}
```

Then open or close DebugKit from your own UI:

```dart
ListTile(
  title: const Text('Open DebugKit'),
  onTap: () {
    DebugKit.open();
  },
);

DebugKit.close();
```

`disableDefaultOverlayButton` only hides the built-in floating launcher button. `DebugKitOverlay` still needs to be mounted once at the app root so the DevTools panel can be shown when requested.

If you plan to call `DebugKit.open()` / `DebugKit.close()` from a debug menu in a `MaterialApp.router` app, keep passing a `navigatorKey` to `DebugKit.init()` so DebugKit has a navigator to use.

### 3. Start Logging

```dart
DebugKit.log.info('App started');
DebugKit.log.debug('Config loaded', metadata: {'env': 'prod'});
DebugKit.log.warning('Slow response from server');
DebugKit.log.error('Auth failed', error: e, stackTrace: s);
DebugKit.log.userAction('Tapped checkout button');
```

### 4. Record State Events

Adapters can send framework-agnostic state events into the dedicated State tab. For JSON-like `Map` / `List` state, DebugKit can show structured changed paths and inline diff snippets instead of just whole-object previews. For arbitrary Dart objects, it falls back to sanitized truncated previews unless the adapter provides structured data. You can also record one manually from app code when you want to annotate a state change:

```dart
DebugKit.state.record(
  DebugStateEvent(
    id: 'manual-1',
    timestamp: DateTime.now(),
    source: 'app',
    name: 'checkoutFlow',
    eventType: DebugStateEventType.updated,
    nextValuePreview: 'step=payment',
  ),
);
```

The State toolbar stays focused on search, event type filtering, pause/resume, and clear actions. Source is still stored on each event and shown in the detail view for debugging, but it is not exposed as a primary filter control.
Search matches provider names, event types, changed paths, and preview values, so you can narrow down nested updates without opening every detail panel.

### 5. Clear Logs

```dart
DebugKit.clearLogs(); // Clears all in-memory logs
```

```dart
DebugKit.clearStateEvents(); // Clears only State tab events
```

```dart
DebugKit.clearNetworkTransactions(); // Clears only network request entries
```

### 6. Disabled Mode

Pass `enabled: false` to completely disable DebugKit. No logs are stored, no overlay is shown, and there is zero runtime overhead:

```dart
DebugKit.init(enabled: kDebugMode);
```

Check the current state at any time:

```dart
if (DebugKit.isEnabled) { ... }
```

### 7. Integration Packages

DebugKit relies on separate optional adapter packages to log automated events without bloating the core:

- [`debug_kit_dio`](https://pub.dev/packages/debug_kit_dio) — Dio HTTP interceptor that feeds the Network Inspector
- [`debug_kit_go_router`](https://pub.dev/packages/debug_kit_go_router) — GoRouter navigation observer
- [`debug_kit_riverpod`](https://pub.dev/packages/debug_kit_riverpod) — Riverpod state observer that records provider changes in the State tab

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
> When network transactions are present, exports also include a sanitized Network Summary section plus a Network Requests section. They are derived from already-stored values only and never include request/response bodies or arbitrary headers.

If the share sheet fails, DebugKit automatically falls back to copying the formatted text to the clipboard and shows a SnackBar notification.


DebugKit uses conservative best-effort sanitization to protect sensitive information before it reaches the in-memory store or exported logs:

- **Smart Masking**: Sensitive values (Tokens, API keys, Passwords) are partially masked based on their length.
  - Very short values (≤ 3 chars) are fully masked as `***`.
  - Longer values preserve a few start and end characters for context (e.g., `abc123secret` → `ab********et`).
- **Natural Language Protection**: Detects and masks secrets in plain text like `User password is: my_secret` or `token=my_token`.
- **Full Redaction**: PEM private key blocks and explicitly labeled mnemonic phrases are fully replaced with `[REDACTED PRIVATE KEY]` / `[REDACTED MNEMONIC]`.
- **Metadata Sanitization**: Metadata keys like `api_key` or `secret` are automatically sanitized.
- **Offline & Local**: DebugKit is strictly local. Logs are only stored in memory and never sent to any server.

Hashes, checksums, canonical hash values, and UUID-like identifiers are not treated as private keys by default.

> [!IMPORTANT]
> While DebugKit provides robust automatic sanitization, developers should still avoid intentionally logging raw production secrets.
> Disabling sanitizer rules can expose secrets in the in-app console, Flutter / IDE console mirroring, exported logs, and shared bug reports.

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

## Network Inspector

The **Network** tab is a compact, mobile-first request inspector that feels like Chrome DevTools on a phone. It requires `debug_kit_dio` to be installed as the data source.

DebugKit shows a lightweight request timeline based on request start time and duration across the currently visible set of requests. Pending requests extend to "now" so they remain visible while they are still in flight. Low-level browser phases such as DNS, TCP, TLS, and TTFB are not available from Dio by default.

Selecting a request highlights that bar and dims the others. Use the timeline header's **Show all** action to clear selection and return to the full set of visible requests. This is separate from **Reset** on the time range brush, which only restores the selected time window.

### Request list

Each request appears as a compact card showing:

- Color-coded method badge (GET blue, POST green, PUT/PATCH amber, DELETE red)
- Path with single-line ellipsis, request ID, and trace name when available
- Status badge (2xx green, 3xx blue, 4xx amber, 5xx red, pending amber)
- Duration label — highlighted amber when the request is slow
- No per-card timeline footer; the shared overview above the list is the primary timeline surface

Tap a card to expand it inline. Only one card expands at a time to keep the list scannable.

### Inline detail tabs

Each expanded card reveals tabbed detail without leaving the list:

| Tab | Contents |
|---|---|
| Overview | Method, URL, status, phase, duration, request ID, trace, backend correlation IDs |
| Headers | Request headers preview / Response headers preview (opt-in via `DebugKitDioConfig`) |
| Request | Sanitized request body preview (opt-in) |
| Response | Sanitized response body preview (opt-in) |
| Error | Error type, message, status, stack trace — only shown when the transaction has an error |
| Timeline | Start time, duration, phase, visible-window timing labels, and the request's relation to the shared timeline brush |

Tap the expand icon (⤢) on any card to open the same content in a full-screen sheet for easier reading.

### Toolbar

- Search field (36px height) matched against path, URL, status, IDs, errors, trace names, and metadata
- Sort button: Newest, Oldest, Longest, Shortest, Status, Method, Path, Phase
- Clear network button (removes only network transactions, not all logs)

### Filter chips

A horizontally scrollable single row of compact chips:

- Method chips: GET, POST, PUT, PATCH, DELETE
- Status chips: All, Pending, Failed, 2xx, 3xx, 4xx, 5xx
- Slow chip: requests above the configured threshold (default 500ms)

Active filter count and request count are shown in a slim banner below the chips.

### Summary strip

A slim horizontally scrollable strip showing: Total, Failed (when > 0), Pending (when > 0), Slow (when > 0), Avg duration.

### Safety defaults

Request and response body previews are opt-in and disabled by default. When not enabled, each tab shows a clear message explaining how to enable capture via `DebugKitDioConfig`. Authorization headers, cookies, and API keys are never captured regardless of config.

Set `slowRequestThresholdMs` in `DebugKit.init()` to change the slow threshold from the 500ms default.

```dart
final summary = DebugKit.controller.buildNetworkSummary();
print('Requests: ${summary.totalRequests}');
print('Slow: ${summary.slowRequests}');
```

If no Dio adapter is installed yet, the Network tab shows an empty state explaining how to enable it.

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
