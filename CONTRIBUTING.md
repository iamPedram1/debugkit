# Contributing to DebugKit

## Contribution Philosophy

DebugKit is built to be lightweight, secure, and developer-friendly. We value code quality, performance, and strict sanitization. This is a monorepo, meaning multiple packages live in this repository but are versioned and published independently.

## Monorepo Structure

- **`packages/`**: Contains the source code for all publishable packages.
- **`examples/`**: Contains example applications demonstrating package usage.
- **`AGENTS.md`**: The engineering constitution that all contributors (human and AI) must follow.

### Package Boundaries

Each package in the `packages/` directory is a standalone unit:
- It must have its own `pubspec.yaml`, `README.md`, `CHANGELOG.md`, and `LICENSE`.
- It must be publishable to pub.dev (unless marked private).
- It should not have unnecessary dependencies on other internal packages unless clearly required (e.g., adapters depending on `debug_kit`).

## Adapter Package Rules

When creating or updating an adapter (e.g., `debug_kit_dio`):
1. **Sanitize First**: Adapters must sanitize all data before passing it to the core logger.
2. **Fail Silently**: Adapters must never crash the host application.
3. **Independent Docs**: Each adapter must have its own setup instructions in its `README.md`.
4. **Minimal Footprint**: Keep the dependency count of adapters as low as possible.

## Commit Discipline

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:`: New features
- `fix:`: Bug fixes
- `docs:`: Documentation changes
- `test:`: Adding or updating tests
- `refactor:`: Code changes that neither fix a bug nor add a feature
- `perf:`: Performance improvements
- `chore:`: Maintenance tasks

**Rules:**
- Commit often after meaningful units of work.
- Avoid huge mixed commits.
- Run validation (analyze/test) before every commit.
- Do not mention AI tools or assistants in commit messages.

## Validation Commands

Run these commands from the root using Melos:

- `melos run analyze`: Static analysis.
- `melos run test`: Unit tests.
- `melos run format`: Code formatting.
- `melos run publish-dry-run`: Pub publish dry-run (for publishable packages).

## Documentation Rules

1. **Root Docs**: `AGENTS.md` and `CONTRIBUTING.md` live only at the root.
2. **Package Docs**: Each package owns its `README.md` and `CHANGELOG.md`.
3. **Release Notes**: Update the package-specific `CHANGELOG.md` for every release-worthy change.
4. **Pub Readiness**: Package-level READMEs must be formatted for high-quality display on pub.dev.

## PR Checklist

- [ ] Code follows project style and lints.
- [ ] Tests added for new logic.
- [ ] Sanitization rules respected.
- [ ] Package `CHANGELOG.md` updated.
- [ ] `melos run analyze` passes.
- [ ] `melos run test` passes.
- [ ] `melos run publish-dry-run` passes.
