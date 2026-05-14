# DebugKit Engineering Constitution (AGENTS.md)

This document serves as the primary engineering constitution for AI agents and human contributors working on the DebugKit package. All changes must adhere to these principles to maintain the project's integrity, performance, and security.

## 1. Project Identity
- **Brand**: DebugKit
- **Dart Package**: `debug_kit`
- **What it is**: A mobile-first, in-app DevTools cockpit for Flutter apps.
- **Monorepo**: This is a multi-package workspace managed by Melos.

## 2. Architecture Principles
- **Adapter-Based**: Core logic remains independent. Integrations (Dio, Riverpod, etc.) are implemented as optional adapters.
- **Small Core**: Keep the `lib/src/core` library minimal and dependency-free.
- **Zero App Assumptions**: No Joyn-specific code, no environment-specific assumptions.
- **Public API Stability**: Protect `DebugKit.init()`, `DebugKit.log.*`, and `DebugKitOverlay`.

## 3. Monorepo Documentation Strategy
- **Global Docs**: `AGENTS.md` and `CONTRIBUTING.md` live ONLY at the repository root. Do NOT duplicate them inside packages.
- **Package Ownership**: Each publishable package MUST own its own `README.md`, `CHANGELOG.md`, and `LICENSE`.
- **Pub.dev Readiness**: Package-specific `README.md` files must be optimized for display on pub.dev, focusing on that package's specific utility and setup.
- **Version Tracking**: Each package tracks its own versions and history in its own `CHANGELOG.md`.

## 4. Current Phase: MVP (Phase 1)
- **Scope**: Manual logging, bounded in-memory storage, sanitization, basic UI console, and export functionality.
- **Forbidden**: Do NOT add adapters for Dio, Talker, Riverpod, Bloc, or Routers unless explicitly requested.

## 5. Security & Sanitization
- **Strict Sanitization**: All log input MUST be sanitized via `DebugLogSanitizer` before reaching the store.
- **Secrets Protection**: Never store raw tokens, passwords, API keys, or cookies. Use masking.
- **Full Redaction**: Private keys and mnemonic phrases must be fully redacted.

## 6. Performance
- **Bounded Store**: Max log count defaults to 300. Oldest entries are evicted automatically.
- **Disabled Overhead**: Logging calls must return immediately with near-zero overhead when disabled.
- **UI Efficiency**: Use `ListView.builder` for log lists. Avoid heavy processing in `build()`.

## 7. Testing Requirements
- Unit tests are required for: Log store eviction, Sanitizer masking/redaction, Filter logic, and Export formatting.
- Any change to the Sanitizer MUST include regression tests.

## 8. Commit Discipline
- **Commit Often**: Commit after each meaningful unit of work.
- **Conventional Commits**: Use clear, descriptive commit messages with standard prefixes (`feat`, `fix`, `docs`, `test`, etc.).
- **Validation First**: Always run `melos run analyze` and `melos run test` before suggesting a commit.
- **No AI Mentions**: Do not mention AI tools, agents, or assistants in commit messages.

## 9. Deliverables
Every task completion MUST include:
1. **Files Changed**: A concise list of modified files.
2. **Validation Results**: Status of `melos run format`, `melos run analyze`, and `melos run test`.
3. **Suggested Commit**: A compliant Conventional Commit message.
