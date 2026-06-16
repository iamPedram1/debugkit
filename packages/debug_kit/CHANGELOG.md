# Changelog

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
