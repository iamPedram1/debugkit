# DebugKit Example App

A complete demonstration of [DebugKit](../../packages/debug_kit) and all official adapter packages working together in a single Flutter app.

## What this demo covers

| Feature | Package | Button in App |
|---|---|---|
| Manual debug/info/warning/error logs | `debug_kit` | **Manual Logs** section |
| Sensitive data masking (password/token) | `debug_kit` | **Sensitive Log** |
| Dio network success | `debug_kit_dio` | **GET Success** |
| Dio network error (404) | `debug_kit_dio` | **GET 404** |
| Slow Dio request demo | `debug_kit_dio` | **Slow Request** |
| Network Summary tab | `debug_kit` + `debug_kit_dio` | **Network** tab |
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
6. Tap **Slow Request** — the Network tab can flag the endpoint as slow.
7. Tap **Push /details** — a navigation push event is logged.
8. Tap **Pop Route** on the details page — a pop event is logged.
9. Tap **Update Provider** — a Riverpod state update log appears.
10. Tap **Trigger Failure** — a Riverpod error log appears in red.
11. Tap **Error** from Manual Logs — the overlay button badge counter increases.
12. Open the DebugKit console by tapping the floating button.
13. Use the **Network** tab to inspect status breakdowns, slow endpoints, and backend correlation IDs.
14. Use the **level/source filter chips** to isolate logs by type.
15. Tap a log entry to **expand** and see metadata, timestamps, and stack traces.
16. Long-press a log entry to **copy** its message to the clipboard.
17. Use the **share** icon in the AppBar to export all logs.
18. Use the **delete** icon to clear all logs.

## Screenshot targets

> Screenshots will be added once the UI is finalized.

To capture the required screenshots for the documentation, follow the exact flow below and save them in `../../docs/assets/screenshots/`:

1. **`overlay-button.png`**: Launch the app, tap the "Error" manual log to increment the badge counter, and capture the floating button.
2. **`console-all-logs.png`**: Tap "Info" and "Warning", open the console, and capture the mixed logs list.
3. **`console-network-log.png`**: Tap "GET Success" and "GET 404", open the console, and capture the network entries showing status codes.
4. **`console-router-log.png`**: Tap "Push /details" and then "Pop Route", open the console, and capture the navigation entries.
5. **`console-riverpod-log.png`**: Tap "Update Provider" and "Trigger Failure", open the console, and capture the state changes and failure log.
6. **`console-sanitized-log.png`**: Tap "Sensitive Log", open the console, and capture the log showing `***` masking.
7. **`console-expanded-log.png`**: Open the console, tap any log to expand it, and capture the revealed metadata, timestamps, and stack traces.

## Running locally

```bash
cd examples/debug_kit_example
flutter run
```
