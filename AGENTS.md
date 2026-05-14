# DebugKit Engineering Constitution (AGENTS.md)

This document serves as the primary engineering constitution for AI agents and human contributors working on the DebugKit package. All changes must adhere to these principles to maintain the project's integrity, performance, and security.

## 1. Project Identity
- **Brand**: DebugKit
- **Dart Package**: `debug_kit`
- **What it is**: A mobile-first, in-app DevTools cockpit for Flutter apps. It provides real-time observability into logs, network transactions, state changes, and routing.
- **What it is NOT**: A replacement for official Flutter DevTools. It is not an app-specific logger or a heavy analytics suite.

## 2. Architecture Principles
- **Adapter-Based**: Core logic remains independent. Integrations (Dio, Riverpod, etc.) are implemented as optional adapters.
- **Small Core**: Keep the `lib/src/core` library minimal and dependency-free.
- **Zero App Assumptions**: No Joyn-specific code, no environment-specific assumptions (except `kDebugMode` or `enabled` flag).
- **Public API Stability**: Protect `DebugKit.init()`, `DebugKit.log.*`, and `DebugKitOverlay`. Breaking changes require a version bump and documentation update.

## 3. Current Phase: MVP (Phase 1)
- **Scope**: Manual logging, bounded in-memory storage, sanitization, basic UI console, and export functionality.
- **Forbidden**: Do NOT add adapters for Dio, Talker, Riverpod, Bloc, or Routers unless explicitly requested.
- **Forbidden**: No issue bundles, AI prompt builders, or reproduction sessions in this phase.

## 4. Folder Structure
- `lib/src/core/`: Models, Controllers, and the Log Store.
- `lib/src/ui/`: Presentation layer (Overlay, Screens, Widgets).
- `lib/src/utils/`: Pure logic (Sanitizer, Exporters, Filters).
- `lib/src/core/adapters/`: Interface for future adapters.

## 5. Security & Sanitization
- **Strict Sanitization**: All log input MUST be sanitized via `DebugLogSanitizer` before reaching the store.
- **Secrets Protection**: Never store raw tokens, passwords, API keys, or cookies. Use masking (e.g., `abc***xyz`).
- **Full Redaction**: Private keys and mnemonic phrases must be fully redacted (e.g., `[REDACTED PRIVATE KEY]`).
- **Export Integrity**: Only sanitized data from the store can be exported.

## 6. Performance
- **Bounded Store**: Max log count defaults to 300. Oldest entries are evicted automatically.
- **Disabled Overhead**: When `enabled: false`, logging calls must return immediately with near-zero overhead.
- **UI Efficiency**: Use `ListView.builder` for log lists. Avoid heavy processing or O(N) operations in `build()`.

## 7. Testing Requirements
- Unit tests are required for: Log store eviction, Sanitizer masking/redaction, Filter logic, and Export formatting.
- Any change to the Sanitizer MUST include regression tests.

## 8. AI Agent Workflow
1. **Inspect**: Read existing code and `AGENTS.md` before making changes.
2. **Focus**: Make small, atomic changes. Avoid unrelated refactors.
3. **Validate**: Always run `flutter analyze` and `flutter test` after changes.
4. **Report**: Summarize changes and validation results in the response.
