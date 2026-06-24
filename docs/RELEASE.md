# DebugKit Release Process

This document describes the process for publishing DebugKit packages to pub.dev.

> [!IMPORTANT]
> Never publish from a dirty git state. Always commit all changes and verify a clean working tree before running `dart pub publish`.

---

## Release Order

Packages must be published in dependency order. Core first, then adapters.

| Order | Package | Version | Notes |
| :---: | :--- | :--- | :--- |
| 1 | `debug_kit` | 0.9.0 | Core — publish first, no local deps |
| 2 | `debug_kit_dio` | 0.5.0 | Depends on `debug_kit` |
| 3 | `debug_kit_go_router` | 0.3.0 | Depends on `debug_kit` |
| 4 | `debug_kit_riverpod` | 0.2.3 | Depends on `debug_kit` |

**Why this order matters:** Adapter packages declare `debug_kit: ^<version>` in their `pubspec.yaml`. If the core has not yet been published, pub.dev cannot resolve the constraint during adapter publication.

---

## Pre-Release Checklist

Run this checklist before every publish:

- [ ] All changes committed and pushed to `main`
- [ ] `git status` shows a clean working tree (no modified or untracked files)
- [ ] Each package `pubspec.yaml` version is correct
- [ ] Each package `CHANGELOG.md` has a matching version section at the top
- [ ] All LICENSE files contain the full MIT text (not the placeholder)
- [ ] All README installation snippets reference pub.dev version constraints (not `git:`)
- [ ] `melos run format` passes with 0 changed files
- [ ] `melos run analyze` passes with no issues
- [ ] `melos run test` passes with 0 failures
- [ ] `melos run publish-dry-run` shows only the expected `pubspec_overrides.yaml` hints and no warnings or errors
- [ ] Git tag has been created for the release (see Tagging below)

---

## Handling `pubspec_overrides.yaml`

Adapter packages use `pubspec_overrides.yaml` for local development to point at the workspace copy of `debug_kit`. This file must **not** be removed from the repository — it is how local development works.

However, pub.dev will flag the overrides as a hint:

```
* Non-dev dependencies are overridden in pubspec_overrides.yaml.
```

This hint is **expected and safe** as long as:
- The published `pubspec.yaml` uses a proper hosted version constraint (`^0.9.0` for `debug_kit`, `^0.5.0` for `debug_kit_dio`), not a `path:` dependency.
- The only issue in the dry-run output is this override hint.

Do **not** delete `pubspec_overrides.yaml` before publishing. The pub tool resolves the hosted constraint from pub.dev when publishing, not from the override file.

---

## Validation Commands

Run from the repository root before every release:

```bash
# 1. Bootstrap the workspace
melos bootstrap

# 2. Verify formatting (must show 0 changed files)
melos run format

# 3. Verify static analysis (must show no issues)
melos run analyze

# 4. Run all tests (must show 0 failures)
melos run test

# 5. Dry-run all publishable packages
melos run publish-dry-run
```

---

## Package-Specific Dry-Runs

Run these before the final publish to inspect per-package output in detail:

```bash
cd packages/debug_kit
dart pub publish --dry-run

cd packages/debug_kit_dio
dart pub publish --dry-run

cd packages/debug_kit_go_router
dart pub publish --dry-run

cd packages/debug_kit_riverpod
dart pub publish --dry-run
```

### Expected dry-run output

| Package | Expected result |
| :--- | :--- |
| `debug_kit` | `Package has 0 warnings.` — or the dirty-git-state warning if uncommitted files exist |
| `debug_kit_dio` | `Package has 1 warning and 1 hint.` — warning: dirty git state (before commit); hint: pubspec_overrides.yaml |
| `debug_kit_go_router` | `Package has 1 warning and 1 hint.` — warning: dirty git state (before commit); hint: pubspec_overrides.yaml |
| `debug_kit_riverpod` | `Package has 1 warning and 1 hint.` — warning: dirty git state (before commit); hint: pubspec_overrides.yaml |

After committing all changes, the dirty-git warning disappears. The pubspec_overrides hint is always present in local development and is safe to ignore — it does not affect the published package.

---

## Changelog Rules

Every publishable release requires a CHANGELOG entry.

### Format

```markdown
# Changelog

## <version>

- <change description>
- <change description>
```

### Rules

- Add entries above the previous version, not below.
- Use present-tense imperative language ("Add", "Fix", "Remove").
- Mention affected public APIs explicitly.
- Do not mention AI tools, agents, or model names.
- The version in CHANGELOG must exactly match the version in `pubspec.yaml`.

---

## Tagging

Create a git tag for each package release. Use the format:

```
<package_name>-v<version>
```

### Examples

```bash
git tag debug_kit-v0.9.0
git tag debug_kit_dio-v0.5.0
git tag debug_kit_go_router-v0.3.0
git tag debug_kit_riverpod-v0.2.3
git push --tags
```

GitHub release title for this core release:

`DebugKit 0.9.0 — Sanitized Console Mirroring`

Tag **after** publishing successfully. Never tag a version that has not been published.

---

## Publishing

Publish packages one at a time in the required order. Wait for each package to appear on pub.dev before publishing the next adapter.

```bash
# Step 1 — Core
cd packages/debug_kit
dart pub publish

# Wait for debug_kit to appear on pub.dev (~5 minutes)

# Step 2 — Dio adapter
cd packages/debug_kit_dio
dart pub publish

# Step 3 — GoRouter adapter
cd packages/debug_kit_go_router
dart pub publish

# Step 4 — Riverpod adapter
cd packages/debug_kit_riverpod
dart pub publish
```

---

## Publish Safety Checklist

> [!CAUTION]
> Violating any of these rules may result in an unpatchable published version.

- **Never** run `dart pub publish` from a dirty git working tree.
- **Never** publish with `path:` dependencies in `pubspec.yaml` (only in `pubspec_overrides.yaml`).
- **Never** publish an adapter before its `debug_kit` dependency version is live on pub.dev.
- **Never** publish if `melos run test` has failures.
- **Never** publish if `melos run analyze` shows errors or warnings.
- **Never** increment the version without a CHANGELOG entry.
- **Never** skip the dry-run step.

---

## Post-Release

After all packages are published:

1. Create and push all version tags.
2. Create a GitHub Release (if using GitHub Releases) pointing at the tag, with the CHANGELOG entries as the body.
3. Update the root README version table to reflect the published versions.
4. Announce in any relevant developer channels.

---

## Versioning Guidelines

DebugKit follows [Semantic Versioning](https://semver.org/):

| Change | Version bump |
| :--- | :--- |
| Breaking public API change | Major (`1.0.0 → 2.0.0`) |
| New non-breaking feature | Minor (`0.1.0 → 0.2.0`) |
| Bug fix, docs, internal refactor | Patch (`0.2.0 → 0.2.1`) |

While `debug_kit` is pre-`1.0.0`, breaking changes may ship in minor versions. Document them clearly in the CHANGELOG.

Adapter packages should increment their version independently when their own behavior changes. Updating the minimum `debug_kit` constraint is considered a breaking change if it forces users to upgrade core.
