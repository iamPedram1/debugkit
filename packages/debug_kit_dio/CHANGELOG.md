# Changelog

## 0.6.1

- Added a package-level example for pub.dev.
- Added missing public API documentation comments.
- Tightened the Dio lower-bound dependency constraint to match the APIs used by the adapter.

## 0.6.0

### Added
- Added opt-in pretty-printed JSON body previews for request and response payloads.
- Added gzip-aware body preview decoding for inspectable compressed payloads.
- Added body skip reasons so the Network Inspector can explain why a preview is unavailable.

### Changed
- Updated the adapter to support `debug_kit ^0.11.0`.

## 0.5.0

### Changed

- Updated the adapter to support `debug_kit ^0.10.0`.

## 0.4.0

- feat: capture safe network transaction metadata needed by the new Network inspector, including sanitized URL parts, host, query, and error details.
- feat: add opt-in preview configuration for request headers, response headers, request bodies, and response bodies with safe defaults.
- fix: keep one request equal to one updateable log entry while preserving cancellation and backend correlation behavior.

## 0.3.0

- feat: capture safe backend correlation IDs from allowlisted response headers only.
- feat: enrich Dio network logs with generic network summary metadata (`kind`, `method`, `path`, `phase`, `status`).
- fix: keep network requests as a single updateable log entry while preserving requestId-based enrichment and cancellation behavior.

## 0.2.2

- chore: update `repository` and `issue_tracker` URLs to reflect repository rename (`username/debug_kit` → `username/debugkit`).

## 0.2.1

- Fix: add `TestWidgetsFlutterBinding.ensureInitialized()` to the test suite so trace store event tests pass reliably when the Flutter scheduler binding is required.
- Bump minimum `debug_kit` constraint to `^0.5.0` to align with the Error Digest release.
- Update README install snippet to current versions.

## 0.2.0

- **Trace correlation**: Dio requests made inside an active `DebugKit.trace.run()` zone now automatically carry `traceId` and `traceName` on the log entry.
- **Network trace events**: A `network` trace event is recorded on the active trace for each request start, response, and error.
- The trace ID is captured at request time from the Zone, so it is correctly associated even across async boundaries.
- No behavior change when no trace is active — all existing logging behavior is preserved.

## 0.1.0

- Initial release of the DebugKit Dio Adapter.
- Log network requests, responses, and errors.
- Automatic sanitization of URLs, query parameters, and headers.
- Support for request IDs to track transaction lifecycles.
- Duplicate attach protection, duration metadata, and improved cancelled request handling.
- Zero overhead when DebugKit is disabled.
