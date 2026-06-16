# Changelog

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
