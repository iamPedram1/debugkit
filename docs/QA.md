# DebugKit Runtime QA Checklist

This document provides a comprehensive checklist for verifying DebugKit's runtime behavior in the example application.

## 1. Setup & Launch
- [ ] Run `melos bootstrap` to ensure all dependencies are linked.
- [ ] Launch the example app: `cd examples/debug_kit_example && flutter run`.
- [ ] App launches without crashes.
- [ ] The DebugKit floating overlay button (cockpit icon) is visible.
- [ ] The overlay button can be dragged across the screen.

## 2. Console Navigation
- [ ] Tapping the overlay button opens the DebugKit console.
- [ ] The console opens with a smooth transition.
- [ ] The console covers the full screen or appears as a modal bottom sheet (depending on implementation).
- [ ] Tapping the close button or system back button closes the console and returns to the app.

## 3. Manual Logging
- [ ] Pressing "Debug" button adds a DEBUG level log.
- [ ] Pressing "Info" button adds an INFO level log.
- [ ] Pressing "Warning" button adds a WARNING level log.
- [ ] Pressing "Error" button adds an ERROR level log with stack trace/error details.
- [ ] Pressing "Sensitive Log" adds a log where the password `my_super_secret_password123` is masked.
    - Expected: `User password is: my_*********************123`

## 4. Adapter Verification
- [ ] **Dio (Network):**
    - [ ] Pressing "GET Success" adds a network log for a 200 OK response.
    - [ ] Pressing "GET 404" adds a network log for a 404 Not Found error.
    - [ ] Network logs show method, URL, status code, and duration.
- [ ] **GoRouter (Navigation):**
    - [ ] Pressing "Push /details" adds a navigation log.
    - [ ] Pressing "Replace Route" adds a navigation log.
    - [ ] Navigation logs show the route path and parameters.
- [ ] **Riverpod (State):**
    - [ ] Pressing "Update Provider" adds a provider update log.
    - [ ] Pressing "Trigger Failure" adds a provider failure log.
    - [ ] Riverpod logs show the provider name and the change/error.

## 5. Console Interactions
- [ ] **Filtering:**
    - [ ] Filtering by Level (e.g., show only Error) works correctly.
    - [ ] Filtering by Source (e.g., show only Network) works correctly.
    - [ ] Search bar filters logs by message content or metadata.
- [ ] **Log Details:**
    - [ ] Tapping a log tile expands it to show full details (metadata, stack trace, etc.).
    - [ ] Long-pressing a log tile (or using the copy icon) copies the log content to the clipboard.
- [ ] **Maintenance:**
    - [ ] Pressing "Clear Logs" (in the app or console) removes all stored logs.
    - [ ] Verify the console updates immediately after clearing.

## 6. Sanitizer Safety
- [ ] Sensitive keys (Authorization, password, etc.) are masked in the console UI.
- [ ] Partial masking is applied for longer secrets (e.g., `sk-proj-123...`).
- [ ] Full redaction is applied for private keys/seed phrases (if applicable).
- [ ] **Export/Copy:**
    - [ ] Copying a sanitized log to the clipboard does NOT reveal the raw secret.
    - [ ] Exporting all logs (if implemented) uses sanitized values only.

## 7. Performance & Stability
- [ ] No visible jank when logging frequently.
- [ ] Log storage is bounded (verify that old logs are evicted when reaching the limit).
- [ ] App remains responsive even with hundreds of logs.
- [ ] **Disabled Mode:**
    - [ ] When `enabled: false` is passed to `DebugKit.init()`, the overlay does not appear and no logs are stored.

## 8. Release Mode & Internal Builds
- [ ] DebugKit should be completely dormant or excluded in production builds based on your app's environment configuration.
- [ ] Verify that `DebugKit.init(enabled: false)` has zero impact on the release app performance.
- [ ] (Optional) In staging or QA builds, ensure that enabling DebugKit does not inadvertently leak sensitive data, even with the sanitizer running, by strictly limiting the log volume and avoiding body payloads.

## 9. Known Limitations
- [ ] Large response bodies are not captured by default (Phase 2 limitation).
- [ ] Persistent storage is not yet implemented (logs are lost on app restart).
- [ ] Binary/Multipart payloads are ignored.
