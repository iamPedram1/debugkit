## Summary

<!-- Briefly describe what this PR changes. -->

## Package(s) Affected

<!-- List the package(s) touched by this PR. -->

Examples:

- `debug_kit`
- `debug_kit_dio`
- `debug_kit_go_router`
- `debug_kit_riverpod`
- `example`
- docs/tooling only

## Type of Change

- [ ] bug fix
- [ ] feature
- [ ] improvement
- [ ] docs
- [ ] refactor
- [ ] tests
- [ ] chore
- [ ] ci

## Motivation

<!-- Why is this change needed? What problem does it solve? -->

## Implementation Notes

<!-- Share important design decisions, tradeoffs, or limitations. -->

## Screenshots / Video

<!-- Include only if the UI changed. Otherwise write "Not applicable". -->

## Security / Sanitization Checklist

- [ ] No raw secrets, tokens, passwords, cookies, API keys, private keys, or mnemonic phrases were added.
- [ ] Logging and export paths still use sanitized values only.
- [ ] No unsafe request/response body capture was introduced.
- [ ] Route extras, provider state, and large objects are not logged unless explicitly safe and documented.
- [ ] Sanitizer behavior was tested if sanitizer logic changed.

## Adapter Checklist

<!-- Complete if this PR changes an adapter package. Otherwise write "Not applicable". -->

- [ ] Adapter does not add dependencies to `debug_kit` core.
- [ ] Adapter imports only public DebugKit APIs, not `package:debug_kit/src/...`.
- [ ] Adapter fails silently and never breaks the host app.
- [ ] Adapter sanitizes data before logging.
- [ ] Adapter documents what it logs and what it intentionally does not log.
- [ ] Adapter tests cover disabled mode and failure safety.

## Testing Checklist

- [ ] Ran the relevant tests locally.
- [ ] Added or updated tests for changed behavior.
- [ ] Verified the affected flow manually if applicable.
- [ ] Verified disabled mode if logging/adapter behavior changed.

## Breaking Changes

<!-- Describe any breaking changes, or write "None". -->

## Linked Issues

<!-- Link related issues or write "None". -->

## Final Checklist

- [ ] ran `melos bootstrap`
- [ ] ran `melos run format`
- [ ] ran `melos run analyze`
- [ ] ran `melos run test`
- [ ] ran `melos run publish-dry-run` if package metadata or release files changed
- [ ] updated README if needed
- [ ] updated CHANGELOG if release-worthy
- [ ] package README remains pub.dev-friendly
- [ ] package `pubspec.yaml` metadata is still valid
- [ ] no raw secrets added
- [ ] no package boundary violations
- [ ] no imports from another package's `src/` directory
- [ ] no new dependency was added to `debug_kit` core without approval
