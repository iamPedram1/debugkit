# DebugKit Engineering Constitution (AGENTS.md)

This document is the primary engineering constitution for AI agents and human contributors working on the DebugKit monorepo. All changes must follow these rules to keep the project clean, scalable, secure, performant, and publishable.

---

## 1. Project Identity

- **Brand**: DebugKit
- **Core Dart package**: `debug_kit`
- **Repository type**: Multi-package Flutter/Dart monorepo managed by Melos
- **What DebugKit is**: A mobile-first, in-app DevTools cockpit for Flutter apps.
- **What DebugKit is not**:
  - Not just a logger.
  - Not a replacement for official Flutter DevTools.
  - Not an app-specific internal tool.

DebugKit helps developers inspect logs, network calls, navigation events, and later state changes directly inside real Flutter apps.

---

## 2. Architecture Principles

- **Adapter-based architecture**: Core logic must remain independent. Integrations such as Dio, Riverpod, Bloc, GoRouter, AutoRoute, Talker, and others must live in optional adapter packages.
- **Small core**: Keep `packages/debug_kit/lib/src/core` minimal, stable, and dependency-light.
- **No state-management lock-in**: The core package must not require Riverpod, Bloc, Provider, GetX, or any other state-management package.
- **Public API stability**: Protect the main public API:
  - `DebugKit.init()`
  - `DebugKit.log.*`
  - `DebugKitOverlay`
  - `DebugKitAdapter`
  - `DebugKitController`
- **Separation of concerns**: Models, controller/store, adapters, UI, sanitization, filtering, and export logic must stay separated.
- **Package-first mindset**: This repository is building pub.dev packages, not internal app utilities.

---

## 3. Monorepo Documentation Strategy

- **Global docs live at the repository root only**:
  - `AGENTS.md`
  - `CONTRIBUTING.md`
  - root `README.md`
- **Do not duplicate `AGENTS.md` or `CONTRIBUTING.md` inside every package** unless explicitly requested.
- **Each publishable package must own its own**:
  - `README.md`
  - `CHANGELOG.md`
  - `LICENSE`
  - `pubspec.yaml`
- **Package README files must be pub.dev-ready** and focused on that package’s specific setup and usage.
- **Each package tracks its own version history** in its own `CHANGELOG.md`.
- Root documentation should explain the workspace, package map, development commands, contribution rules, and roadmap.

---

## 4. Current Phase Boundaries

### Phase 1 — Core MVP

The core `debug_kit` package includes:

- manual logging
- bounded in-memory log store
- sanitization
- searchable/filterable log console
- draggable overlay button
- copy/export logs
- example app
- package README
- tests

### Phase 2 — Adapter Packages

Adapters must be separate packages, such as:

- `debug_kit_dio`
- `debug_kit_go_router`
- `debug_kit_riverpod`
- `debug_kit_bloc`
- `debug_kit_talker`

### Forbidden unless explicitly requested

Do not add the following to core or start them without a direct task:

- new adapter packages
- issue bundles
- AI prompt builder
- snapshots
- reproduction sessions
- diagnose dashboard
- command palette
- network inspector UI
- route timeline UI
- persistent storage
- request/response body capture

---

## 5. Expected Repository Structure

```text
debugkit/
  AGENTS.md
  CONTRIBUTING.md
  README.md
  LICENSE
  melos.yaml
  pubspec.yaml
  packages/
    debug_kit/
      README.md
      CHANGELOG.md
      LICENSE
      pubspec.yaml
      lib/
      test/
    debug_kit_dio/
      README.md
      CHANGELOG.md
      LICENSE
      pubspec.yaml
      pubspec_overrides.yaml
      lib/
      test/
    debug_kit_go_router/
      README.md
      CHANGELOG.md
      LICENSE
      pubspec.yaml
      pubspec_overrides.yaml
      lib/
      test/
  examples/
    debug_kit_example/
```

---

## 6. Core Package Structure Rules

The core package should follow this structure:

```text
packages/debug_kit/lib/
  debug_kit.dart
  src/
    core/
      controller/
      models/
      store/
      adapters/
    ui/
      overlay/
      screens/
      widgets/
    utils/
      sanitizer/
      export/
      filtering/
```

### What belongs where

- `core/models/`: plain data models and enums.
- `core/controller/`: public/internal controller orchestration.
- `core/store/`: bounded in-memory store logic.
- `core/adapters/`: generic adapter interface only, not concrete third-party adapters.
- `ui/`: overlay, console screen, tiles, filters, and reusable UI pieces.
- `utils/sanitizer/`: all masking/redaction logic.
- `utils/export/`: pure export formatting and file/share helpers.
- `utils/filtering/`: log filtering/search logic.

---

## 7. Public API Rules

- Only export intentional public APIs from package entrypoints.
- Do not expose `src/` internals directly.
- Adapter packages must import from public package APIs, not from another package’s `src/` directory.
- Do not rename public APIs casually.
- Any public API change must update:
  - package README
  - package CHANGELOG
  - tests
  - example app if affected
- Breaking changes require an explicit reason and versioning plan.

---

## 8. Dependency Rules

- Do not add heavy dependencies without explicit approval.
- The core `debug_kit` package must not depend on Dio, Riverpod, Bloc, GoRouter, AutoRoute, Talker, Firebase, Sentry, analytics SDKs, or app-specific libraries.
- Adapter dependencies belong only in adapter packages.
- Adapter packages should depend only on:
  - `debug_kit`
  - the integration package they support
  - minimal Flutter/Dart dependencies
- Prefer Flutter/Dart standard primitives before adding dependencies.
- Avoid generated code unless clearly justified.
- Do not add dependencies for convenience if a small local implementation is enough.

---

## 9. Monorepo Dependency Overrides

Adapter packages should use hosted version constraints in `pubspec.yaml` for publishable dependencies.

For local development, use `pubspec_overrides.yaml` to point adapter packages to local workspace packages.

### Example

```yaml
# pubspec.yaml
dependencies:
  debug_kit: ^0.1.0
```

```yaml
# pubspec_overrides.yaml
dependency_overrides:
  debug_kit:
    path: ../debug_kit
```

### Rules

- Do not use `path:` dependencies directly in publishable package `pubspec.yaml` files.
- Do not import from another package’s `src/` directory.
- `pubspec_overrides.yaml` is allowed for local development only.
- Before real publishing, verify that overrides are removed, ignored, or handled by the release pipeline.
- If `dart pub publish --dry-run` fails only because of local overrides, document it clearly in the task summary.
- Do not treat local override dry-run warnings as architecture failures unless other warnings/errors exist.

---

## 10. Security and Sanitization Rules

- All log input must be sanitized before reaching the store.
- Never store raw:
  - access tokens
  - refresh tokens
  - authorization headers
  - cookies
  - API keys
  - passwords
  - private keys
  - mnemonic or seed phrases
- Mask ordinary secrets.
- Fully redact private keys and mnemonic/seed phrases.
- Exported logs must only use already-sanitized stored values.
- Adapter packages must sanitize data before pushing logs into DebugKit.
- Do not log request or response bodies by default.
- Do not inspect binary/multipart payloads.
- Any sanitizer change requires regression tests.

---

## 11. Performance Rules

- Disabled mode must have near-zero overhead.
- Logging calls must return quickly when disabled.
- Log store must be bounded. Default max log count is 300.
- Do not introduce unbounded memory growth.
- Do not perform heavy processing inside `build()`.
- Use `ListView.builder` for log lists.
- Avoid rebuild storms.
- Avoid JSON pretty-printing, large stringification, or body parsing in adapters.
- Export formatting should be pure and testable.
- Adapters must never block host app behavior.
- Adapters must fail silently and never crash the host app.

---

## 12. UI Rules

- UI must be mobile-first.
- Console should use a clean, readable dark theme.
- Logs should be easy to scan.
- Avoid visual noise.
- Overlay must not block normal app usage.
- Overlay button must remain draggable and clamped to usable screen bounds.
- Console must work on small screens.
- No dependency on host app themes/components.
- Do not add complex dashboards before the relevant phase.

---

## 13. Adapter Rules

The core adapter contract is:

```dart
abstract class DebugKitAdapter {
  void attach(DebugKitController controller);
  void dispose();
}
```

Adapter rules:

- Adapters are optional.
- Adapters live in their own publishable packages where possible.
- Adapters must not pollute core.
- Adapters must sanitize before logging.
- Adapters must be independently testable.
- Adapters must fail silently.
- Adapters must never break the host application.
- Adapters must avoid body logging by default.
- Adapters must document what they log and what they intentionally do not log.
- Adapter packages must have their own README, CHANGELOG, LICENSE, pubspec, and tests.

---

## 14. Testing Requirements

Tests are required for:

- log store append/clear behavior
- max buffer eviction
- disabled mode
- controller logging behavior
- sanitizer masking
- sanitizer full redaction
- filtering by level/source/search
- export formatter output
- adapter attach/dispose lifecycle
- adapter disabled behavior
- adapter sanitization behavior
- adapter failure safety

Rules:

- Any sanitizer change requires regression tests.
- Any adapter behavior change requires adapter tests.
- Avoid fragile widget tests unless they protect meaningful behavior.
- Prefer small unit tests for core logic.

---

## 15. Documentation Rules

Update documentation when behavior changes.

### Update package README when:

- public API changes
- setup changes
- new adapter usage is added
- security/performance behavior changes
- limitations change

### Update package CHANGELOG when:

- a release-worthy change is made
- public API changes
- behavior changes
- bug fixes are made
- docs or package metadata change for release readiness

### Update root README when:

- package map changes
- roadmap changes
- workspace commands change
- new package is added

### Update CONTRIBUTING/AGENTS when:

- architecture rules change
- validation commands change
- release process changes
- adapter rules change

---

## 16. Validation Commands

Run from the repository root unless a task says otherwise:

```bash
melos bootstrap
melos run format
melos run analyze
melos run test
```

For package-readiness or release-related tasks, also run:

```bash
melos run publish-dry-run
```

If necessary, run package-specific dry-runs:

```bash
cd packages/debug_kit
dart pub publish --dry-run
```

```bash
cd packages/debug_kit_dio
dart pub publish --dry-run
```

Expected local-development caveat:

- Adapter package dry-runs may warn/fail because of `pubspec_overrides.yaml` or local unpublished dependencies.
- If the only issue is local override/path dependency behavior, document it clearly.
- Fix all other warnings/errors.

---

## 17. Commit Discipline

Agents and contributors must commit often and follow the project commit convention.

### When to commit

Create a commit after each complete, meaningful unit of work, such as:

- package structure changes
- public API changes
- sanitizer/security changes
- UI/overlay changes
- adapter implementation
- documentation updates
- test additions/fixes
- publish-readiness fixes
- tooling/monorepo changes

Do not bundle unrelated work into one large commit.

Prefer small commits that are easy to review and revert.

### Commit convention

Use Conventional Commits:

```text
<type>: <short summary>
```

Allowed types:

- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation-only change
- `test:` tests added/updated
- `refactor:` code restructuring without behavior change
- `perf:` performance improvement
- `chore:` tooling, workspace, config, maintenance
- `ci:` CI/CD changes
- `style:` formatting only

Examples:

```bash
git commit -m "feat: bootstrap DebugKit MVP package"
git commit -m "docs: add agent engineering guidelines"
git commit -m "chore: prepare DebugKit monorepo workspace"
git commit -m "fix: sanitize stack traces before storage"
git commit -m "test: cover log store eviction behavior"
```

### Commit message rules

- Keep the subject short and clear.
- Use imperative mood where possible.
- Do not mention AI tools, agents, assistants, or model names in commit messages.
- Do not use vague messages like:
  - `update`
  - `fix stuff`
  - `changes`
  - `wip`
  - `final`
- If the commit affects public API, update README and CHANGELOG in the same commit.

---

## 18. AI Agent Workflow

Before editing:

1. Read `AGENTS.md`.
2. Inspect relevant code and package boundaries.
3. Understand the current phase and scope.
4. Avoid unrelated refactors.

During work:

- Make small focused changes.
- Do not add surprise dependencies.
- Do not start future phases unless requested.
- Do not rewrite large files without reason.
- Preserve existing public APIs unless the task requires changing them.
- Add tests for changed behavior.
- Keep docs aligned with implementation.

After work:

- Run required validation commands.
- Summarize files changed.
- Summarize validation results.
- Explain any expected dry-run warnings.
- Suggest or create a Conventional Commit.

---

## 19. Forbidden Changes

Do not:

- add backend-specific assumptions
- add Firebase/Sentry/analytics SDKs
- add Dio/Riverpod/Bloc/GoRouter dependencies to core
- add adapter dependencies to core
- import another package’s `src/` directory
- log raw request/response bodies by default
- log route extra objects
- stringify large objects for logging
- store raw secrets
- create unbounded log storage
- do heavy processing in UI build methods
- manually edit generated files
- publish packages from a dirty or unverified state
- add new adapter packages unless explicitly requested

---

## 20. Done Criteria

A task is complete only when:

- code compiles
- formatting passes
- analysis passes
- tests pass
- docs are updated if needed
- package changelog is updated if release-worthy
- no public API drift occurred unless intentional
- no sanitizer regression exists
- no unnecessary dependency was added
- package boundaries are respected
- validation results are reported
- a Conventional Commit message is suggested or created

Every task completion must include:

1. **Files changed**
2. **Validation results**
3. **Suggested commit**
4. **Remaining risks or follow-ups**

---

## 21. Communication Style

Be direct, practical, and focused.

Prefer:

- simple over clever
- small over huge
- explicit over magical
- package quality over internal shortcuts
- safety over convenience

DebugKit should feel polished, trustworthy, and easy to integrate in under five minutes.
