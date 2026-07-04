# Changelog

## 0.4.1

- Added a package-level example for pub.dev.
- Added missing public API documentation comments.

## 0.4.0

### Changed
- Updated the adapter to support `debug_kit ^0.11.0`.
- Improved route metadata so unnamed routes fall back to readable route labels instead of `unknown`.

## 0.3.0

### Changed

- Updated the adapter to support `debug_kit ^0.10.0`.

## 0.2.2

- chore: update `repository` and `issue_tracker` URLs to reflect repository rename (`username/debug_kit` → `username/debugkit`).

## 0.2.1

- Fix: add `TestWidgetsFlutterBinding.ensureInitialized()` to the test suite so trace store event tests pass reliably when the Flutter scheduler binding is required.
- Bump minimum `debug_kit` constraint to `^0.5.0` to align with the Error Digest release.
- Update README install snippet to current versions.

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
