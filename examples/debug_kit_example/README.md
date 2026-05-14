# DebugKit Example App

A complete demonstration of [DebugKit](../../packages/debug_kit) and all official adapter packages working together in a single Flutter app.

## What this demo covers

| Feature | Package | Button in App |
|---|---|---|
| Manual debug/info/warning/error logs | `debug_kit` | **Manual Logs** section |
| Sensitive data masking (password/token) | `debug_kit` | **Sensitive Log** |
| Dio network success | `debug_kit_dio` | **GET Success** |
| Dio network error (404) | `debug_kit_dio` | **GET 404** |
| GoRouter navigation push/replace | `debug_kit_go_router` | **Navigation** section |
| Riverpod provider update | `debug_kit_riverpod` | **Update Provider** |
| Riverpod provider failure | `debug_kit_riverpod` | **Trigger Failure** |
| Clear all logs | `debug_kit` | **Clear Logs** |

## Demo flow for screenshots

Follow this sequence to produce a rich, varied log console for screenshots:

1. **Launch** the app. The DebugKit floating bug icon appears in the bottom-right corner.
2. Tap **Info** and **Warning** to create baseline manual logs.
3. Tap **Sensitive Log** — observe the masked password in the console.
4. Tap **GET Success** — a network log with HTTP 200 appears.
5. Tap **GET 404** — a network error log appears in red.
6. Tap **Push /details** — a navigation push event is logged.
7. Tap **Pop Route** on the details page — a pop event is logged.
8. Tap **Update Provider** — a Riverpod state update log appears.
9. Tap **Trigger Failure** — a Riverpod error log appears in red.
10. Tap **Error** from Manual Logs — the overlay button badge counter increases.
11. Open the DebugKit console by tapping the floating button.
12. Use the **level/source filter chips** to isolate logs by type.
13. Tap a log entry to **expand** and see metadata, timestamps, and stack traces.
14. Long-press a log entry to **copy** its message to the clipboard.
15. Use the **share** icon in the AppBar to export all logs.
16. Use the **delete** icon to clear all logs.

## Screenshot targets

> Screenshots will be added once the UI is finalized.

Planned screenshots:
- `docs/screenshots/overlay_button.png` — floating DebugKit button with error badge
- `docs/screenshots/console_logs.png` — console with mixed log levels visible
- `docs/screenshots/filter_bar.png` — filter chips in active state
- `docs/screenshots/expanded_log.png` — single log with metadata expanded
- `docs/screenshots/network_log.png` — Dio network entry with status code
- `docs/screenshots/riverpod_log.png` — provider failure entry

## Running locally

```bash
cd examples/debug_kit_example
flutter run
```
