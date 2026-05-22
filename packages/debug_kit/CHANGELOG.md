# Changelog

## 0.2.2

- **Smart Masking**: Replaced static `***` masking with a length-aware algorithm that preserves context while protecting secrets.
- **Natural Language Sanitization**: Improved detection of secrets in plain text messages (e.g., `User password is: ...`).
- **Metadata Sanitization**: Log metadata is now automatically sanitized based on sensitive key patterns.
- **Security Audit**: Conservative regex updates to prevent false positives like masking "Password screen opened" and to prevent over-masking normal sentences as mnemonics.
- **Core Architecture**: Removed hidden UI scheduler coupling (`addPostFrameCallback`) from core state notifications.


## 0.2.1

- **Overlay button**: Improved drag clamping using absolute `Positioned` layout; larger touch target (56px); gradient background; error state turns button red with glow effect.
- **Log tile**: Added colored left accent bar per log level for instant scanability; chevron expand indicator; long-press-to-copy message; full timestamp visible in expanded view; improved monospace block styling.
- **Filter bar**: Source chips now use per-source colors (purple for Riverpod, cyan for Router, etc.); removed checkmarks from chips for cleaner look; compact density; explicit border on search field.
- **Console screen**: Log count subtitle in AppBar; two distinct empty states ("No logs yet" vs "No matching logs"); improved clear confirmation dialog styling.
- Updated example app README with a 16-step screenshot demo flow and feature table.

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
