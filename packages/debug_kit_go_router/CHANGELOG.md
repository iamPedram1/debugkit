# Changelog

## 0.2.0

- **Trace correlation**: Navigation events that occur inside an active `DebugKit.trace.run()` zone now automatically carry `traceId` and `traceName` on the log entry.
- **Navigation trace events**: A `navigation` trace event is recorded on the active trace for each push, pop, replace, and remove event.
- No behavior change when no trace is active — all existing logging behavior is preserved.

## 0.1.0

- Initial release of the DebugKit GoRouter Adapter.
- Log navigation events (push, pop, replace, remove).
- Automatic sanitization of sensitive query parameters in routes.
- Safe metadata extraction without stringifying large `extra` payloads.
- Zero overhead when DebugKit is disabled.
