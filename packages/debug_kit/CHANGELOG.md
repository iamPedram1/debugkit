# Changelog

## 0.2.0

- Added `DebugKit.clearLogs()` convenience method to clear the log store without accessing the controller directly.
- Added `DebugKit.isEnabled` getter to safely query initialization state.
- Removed accidental public export of `DebugKitConsoleScreen` (internal UI, not intended for direct use).
- Cleaned up stale `debugkit.dart` placeholder file.

## 0.1.0

- Initial MVP release of DebugKit.
- Support for manual logging (debug, info, warning, error, userAction).
- In-memory bounded log store (default 300 entries).
- Draggable overlay button with error badge.
- Searchable and filterable log console.
- Automatic sanitization (masking/redaction) of sensitive data.
- Stack trace trimming (max 25 lines).
- Log export to clipboard and file sharing.
- Adapter architecture support for external integrations (e.g., Dio).
- Example app demonstration.
