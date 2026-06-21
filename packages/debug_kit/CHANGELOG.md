# Changelog

## 0.7.0

- feat: add a Chrome-style Network inspector with searchable, filterable request rows, detail sheets, sorting, and a lightweight waterfall.
- feat: introduce `DebugNetworkTransaction` plus transaction builders, filter state, and selective network clearing.
- feat: expose `DebugKit.clearNetworkTransactions()` and a transaction-aware export section for network requests.
- feat: update exports and the example app to surface the new network transaction details and compact overview strip.
- fix: derive Network Summary from normalized network transactions and keep malformed network metadata ignored safely.

## 0.6.0

- feat: add Network Summary models, builder, console tab, and export section.
- feat: expose `DebugKitController.buildNetworkSummary()` and `DebugKit.init(slowRequestThresholdMs:)`.
- feat: add public network summary models for endpoint and status breakdowns.
- fix: keep network summary generation bounded to the in-memory log store and ignore malformed network metadata safely.

## 0.5.2

- fix: widen `share_plus` constraint to `">=10.0.0 <14.0.0"` (was `^10.0.0`) to allow apps using share_plus 11, 12, or 13.
- fix: widen `intl` constraint to `">=0.19.0 <0.21.0"` (was `^0.19.0`) to allow apps using intl 0.20.x.
- No runtime behavior changes. No API changes.

## 0.5.1

- chore: update `repository` and `issue_tracker` URLs to reflect repository rename (`username/debug_kit` → `username/debugkit`).

## 0.5.0

### New: Error Digest / Error Intelligence

DebugKit now groups repeated and related errors into a digest so you can immediately
see what failed, how often, and where — instead of scrolling through raw logs.

#### Error Digest Model

- **`DebugErrorDigest`**: on-demand snapshot of all distinct error classes in the
  current session. Contains `totalErrors`, `uniqueErrors`, `failedTraceCount`,
  `failedNetworkCount`, sorted `entries`, `topRepeatedErrors`, and `latestErrors`.
- **`DebugErrorDigestEntry`**: a single grouped error class with: `fingerprint`,
  `title`, `message`, `normalizedMessage`, `severity`, `source`, `count`,
  `firstSeenAt`, `lastSeenAt`, `relatedTraceIds`, `relatedTraceNames`,
  `relatedRequestIds`, `relatedRoutes`, `relatedProviderNames`, `latestError`,
  `latestStackTrace`, `firstUsefulStackFrame`, and `healthHints`.
- **`DebugErrorDigestSeverity`**: `fatal`, `error`, `warning` — used for sorting
  and color-coding in the UI.

#### Error Fingerprinting

- **`DebugErrorFingerprintBuilder`**: stable, collision-resistant fingerprint strategy.
  - Dio errors: fingerprinted by `method|path|statusCode` — different status codes
    never group; different paths never group.
  - Riverpod failures: fingerprinted by `provider_name|error_type_prefix` — different
    providers never group.
  - App/trace errors: fingerprinted by `error_type_prefix|normalized_message|first_useful_frame`.
  - Volatile values stripped: durations (`after 5000ms`), UUIDs, memory addresses.
  - `DebugErrorFingerprintBuilder.normalizeMessage()` is public for testing.

#### Digest Builder

- **`DebugErrorDigestBuilder.build(logs:, traces:)`**: pure, stateless builder.
  - Sources errors from: `level == error` logs, warning-level logs with an `error`
    field, and failed `DebugTrace` instances.
  - `DebugLogEntry.repeatCount` contributes to the digest entry count.
  - Collects related trace IDs/names, request IDs, route paths, and provider names
    from log metadata.
  - Sorts entries: severity → count → most recent.

#### Controller and Facade

- **`DebugKitController.buildErrorDigest()`**: builds and returns a `DebugErrorDigest`
  from the current store snapshot. Returns an empty digest when disabled.
- **`DebugKit.errors.buildDigest()`**: public facade. On-demand — do not call on
  every frame.

#### Console UI: Errors Tab

- New **Errors** tab (third tab alongside Logs and Traces).
- Summary bar: unique error count, total occurrences, failed network count, failed
  trace count.
- Error list: severity badge, title, count badge (×N), source chip, last-seen time,
  first useful stack frame, related trace/provider/request chips.
- **Error detail screen**: full message, count, first/last seen, latest error,
  stack trace with first useful frame, related traces, request IDs, routes, providers,
  and health hints. Copy summary action.
- Empty state: "No errors detected" when no errors are present.

#### Export

- `.txt` export now includes a `DebugKit Error Digest` section after the Traces
  section when errors are present.
- Each entry exports: severity, source, count, first/last seen, error, frame, traces,
  requests, routes, providers, hints, and first 10 stack trace lines.
- Export is never expanded into N duplicate lines for grouped errors.
- `DebugLogExportFormatter.formatLogs()` now accepts an optional `digest` parameter.
- `DebugErrorDigestExportFormatter` is available for standalone digest formatting.
- `DebugLogFileExporter.exportToClipboard()` and `shareLogs()` now accept an
  optional `digest` parameter — the console passes it automatically.

#### Security

- All digest fields contain only already-sanitized values from the store.
- No raw secrets, tokens, request/response bodies, route extras, or provider state
  objects are stored in any digest field.
- Fingerprinting operates on sanitized stored values — raw secrets never reach the
  comparison logic.

#### Performance

- Digest is computed on demand, not on every frame or every log append.
- Builder is pure and stateless — no background processing, no subscriptions.
- Disabled mode returns an empty digest immediately with zero overhead.
- No unbounded memory growth: the digest is a transient snapshot, not a store.

#### Example App

- New "Error Digest" section with: repeated error ×5, unique error, failed trace
  error, Dio 404 error — all visible in the Errors tab.

## 0.4.0

### New: Repeated Log Grouping

Consecutive identical log entries are now collapsed into a single row with a
repeat counter, mirroring Chrome DevTools console behavior.

- **`groupRepeatedLogs` config option**: enabled by default. Pass
  `groupRepeatedLogs: false` to `DebugKit.init()` to store every emission as
  an independent row.
- **Consecutive-only grouping**: only back-to-back duplicates are merged.
  `A A B A` becomes `A×2 · B · A` — not `A×3 · B`. This is predictable and
  matches DevTools behavior.
- **Network logs never group**: entries carrying a `requestId` (all Dio logs)
  are always stored as separate rows. The Dio adapter updates each entry
  in-place by `requestId` — merging concurrent identical requests would
  silently lose network transaction state. Each network entry occupies its
  own slot regardless of `groupRepeatedLogs`.
- **`DebugLogEntry.repeatCount`**: new field, defaults to `1`. Incremented by
  the store when a duplicate is detected.
- **`DebugLogEntry.lastSeenAt`**: new field. Set to `DateTime.now()` on each
  repeat; `null` when `repeatCount == 1`. The original `timestamp` always
  reflects the *first* occurrence.
- **`DebugLogEntry.fingerprint`**: new computed getter used by the store for
  grouping decisions. Includes `level`, `source`, `message`, `error`, first
  stack trace line, `traceId`, and stable metadata. Excludes `id`, `timestamp`,
  `repeatCount`, `duration_ms`, and `response_headers`.
- **`DebugLogEntry.copyWithRepeatIncrement`**: new helper used by the store.
- **Console UI**: `×N` repeat badge shown in the log tile header when
  `repeatCount > 1`. Expanded view shows **Repeat**, **First seen**, and
  **Last seen** blocks. Long-press copy includes `×N` prefix.
- **Export**: grouped entries export as a single block with `×N` in the header
  line and `First seen` / `Last seen` timestamps. Never expanded into N lines.
- **`maxLogs` counting**: grouped entries occupy one slot regardless of how
  many times the log was emitted. Repeats never trigger unnecessary eviction.
- **Example app**: new "Repeat Log ×5" button demonstrates the feature.

### Security
- Fingerprint is computed on already-sanitized values — raw secrets never
  reach the comparison logic.
- Volatile metadata keys (`duration_ms`, `request_id`, `response_headers`)
  are excluded from the fingerprint so network error retries group safely
  without leaking per-request data.

## 0.3.0

### New: Trace System

- **`DebugKit.trace` API**: Full trace lifecycle — `start()`, `step()`, `end()`, `fail()`, `cancel()`, and `run()`.
- **Scoped async traces**: `DebugKit.trace.run('name', callback)` wraps async callbacks in a Dart Zone that propagates the active trace ID. Marks success on return, failure on throw, and always rethrows the original exception.
- **Nested traces**: `parentTraceId` is automatically set when `run()` is called inside another active `run()` zone.
- **Zone-based correlation**: Logs, Dio requests, GoRouter navigation, and Riverpod failures emitted inside an active trace automatically carry `traceId` and `traceName`.
- **`DebugTraceStore`**: Bounded in-memory store (default 50 traces, 200 events per trace). Evicts oldest completed traces when full.
- **`DebugTraceAnalyzer`**: Lightweight stateless health analyzer. Warns on failed traces, slow traces, stale running traces, failed network events, high event counts, and repeated errors.
- **Trace Console UI**: New "Traces" tab in the DebugKit console. Shows trace list with status badge, duration, event count, and health indicator. Tap any trace to see its full timeline.
- **Trace Detail Screen**: Timeline of events with elapsed time, type badge, metadata, request IDs, and errors. Copy trace summary to clipboard.
- **Export**: `.txt` export now includes a full Traces section with timelines, health warnings, and a failed-trace summary.
- **`DebugKit.clearTraces()`**: Clears all in-memory traces.
- **New `DebugKit.init()` parameters**: `maxTraces`, `maxTraceEventsPerTrace`, `slowTraceThreshold`.

### Security
- All trace metadata, event messages, and error summaries are sanitized before storage.
- No request/response bodies, route extras, or provider state objects are stored in traces.

### Performance
- Trace store is bounded — no unbounded memory growth.
- Disabled mode is a strict no-op for all trace calls.
- No heavy processing in build methods; `ListView.builder` used for all lists.

## 0.2.3

- **Export**: Filename format updated to `debugkit-logs-YYYYMMDD-HHMMSS.txt`.
- **Export**: Share button now exports filtered logs when filters are active.
- **Export**: Empty-log guard and share fallback to clipboard.
- **Smart Masking**: Length-aware masking algorithm.
- **Natural Language Sanitization**: Improved detection of secrets in plain text.
- **Metadata Sanitization**: Log metadata automatically sanitized.

## 0.2.1

- **Overlay button**: Improved drag clamping, larger touch target, gradient background, error state.
- **Log tile**: Colored left accent bar, chevron expand indicator, long-press-to-copy.
- **Filter bar**: Per-source colors, compact density.
- **Console screen**: Log count subtitle, distinct empty states.

## 0.2.0

- Added `DebugKit.clearLogs()` and `DebugKit.isEnabled`.
- Removed accidental public export of `DebugKitConsoleScreen`.

## 0.1.0

- Initial MVP release.


### New: Trace System

- **`DebugKit.trace` API**: Full trace lifecycle — `start()`, `step()`, `end()`, `fail()`, `cancel()`, and `run()`.
- **Scoped async traces**: `DebugKit.trace.run('name', callback)` wraps async callbacks in a Dart Zone that propagates the active trace ID. Marks success on return, failure on throw, and always rethrows the original exception.
- **Nested traces**: `parentTraceId` is automatically set when `run()` is called inside another active `run()` zone.
- **Zone-based correlation**: Logs, Dio requests, GoRouter navigation, and Riverpod failures emitted inside an active trace automatically carry `traceId` and `traceName`.
- **`DebugTraceStore`**: Bounded in-memory store (default 50 traces, 200 events per trace). Evicts oldest completed traces when full.
- **`DebugTraceAnalyzer`**: Lightweight stateless health analyzer. Warns on failed traces, slow traces, stale running traces, failed network events, high event counts, and repeated errors.
- **Trace Console UI**: New "Traces" tab in the DebugKit console. Shows trace list with status badge, duration, event count, and health indicator. Tap any trace to see its full timeline.
- **Trace Detail Screen**: Timeline of events with elapsed time, type badge, metadata, request IDs, and errors. Copy trace summary to clipboard.
- **Export**: `.txt` export now includes a full Traces section with timelines, health warnings, and a failed-trace summary.
- **`DebugKit.clearTraces()`**: Clears all in-memory traces.
- **New `DebugKit.init()` parameters**: `maxTraces`, `maxTraceEventsPerTrace`, `slowTraceThreshold`.

### Security
- All trace metadata, event messages, and error summaries are sanitized before storage.
- No request/response bodies, route extras, or provider state objects are stored in traces.

### Performance
- Trace store is bounded — no unbounded memory growth.
- Disabled mode is a strict no-op for all trace calls.
- No heavy processing in build methods; `ListView.builder` used for all lists.

## 0.2.3

- **Export**: Filename format updated to `debugkit-logs-YYYYMMDD-HHMMSS.txt`.
- **Export**: Share button now exports filtered logs when filters are active.
- **Export**: Empty-log guard and share fallback to clipboard.
- **Smart Masking**: Length-aware masking algorithm.
- **Natural Language Sanitization**: Improved detection of secrets in plain text.
- **Metadata Sanitization**: Log metadata automatically sanitized.

## 0.2.1

- **Overlay button**: Improved drag clamping, larger touch target, gradient background, error state.
- **Log tile**: Colored left accent bar, chevron expand indicator, long-press-to-copy.
- **Filter bar**: Per-source colors, compact density.
- **Console screen**: Log count subtitle, distinct empty states.

## 0.2.0

- Added `DebugKit.clearLogs()` and `DebugKit.isEnabled`.
- Removed accidental public export of `DebugKitConsoleScreen`.

## 0.1.0

- Initial MVP release.
