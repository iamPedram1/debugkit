# Changelog

## 0.2.3

### Changed

- Updated the Riverpod 2 adapter line to support `debug_kit ^0.9.0`.
- Kept compatibility with Riverpod 2 `ProviderObserver` APIs.
- Kept Riverpod logs flowing through DebugKit core so in-app logs and sanitized console mirroring share the same pipeline.

### Notes

- Riverpod 2 users should use `debug_kit_riverpod ^0.2.3`.
- Riverpod 3 support will be introduced separately in `debug_kit_riverpod 0.3.0`.

## 0.2.2

- fix: widen `flutter_riverpod` constraint to `">=2.0.0 <4.0.0"` (was `^2.0.0`) to allow apps using Riverpod 3.x.
- chore: update `repository` and `issue_tracker` URLs to reflect repository rename.
- No runtime behavior changes. `ProviderObserver.providerDidFail` and `didUpdateProvider` are unchanged in Riverpod 3.
- No API changes.

## 0.2.1

- Fix: add `TestWidgetsFlutterBinding.ensureInitialized()` to the test suite so trace store event tests pass reliably when the Flutter scheduler binding is required.
- Bump minimum `debug_kit` constraint to `^0.5.0` to align with the Error Digest release.
- Update README install snippet to current versions.

## 0.2.0

- **Trace correlation**: Provider failures that occur inside an active `DebugKit.trace.run()` zone now automatically carry `traceId` and `traceName` on the log entry.
- **State trace events**: A `state` trace event is recorded on the active trace when a provider fails inside a trace.
- No behavior change when no trace is active — all existing logging behavior is preserved.

## 0.1.0

- Initial release of `debug_kit_riverpod`.
- Added `DebugKitRiverpodObserver` to log provider failures and optional state updates.
- Added `DebugKitRiverpodConfig` to manage log behavior and verbosity safely.
- Included security sanitization to mask obvious secrets in value previews.
