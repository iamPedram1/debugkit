# Security Policy

DebugKit is a debugging/logging package. Because logs may accidentally contain sensitive data, we take sanitizer bypasses and raw secret leaks seriously.

## Reporting Sensitive Issues

Please do not post real tokens, passwords, API keys, cookies, private keys, or mnemonic phrases in public issues.

If you find a case where DebugKit stores or exports a raw secret, please open an issue using fake example values only.

If the report requires sharing sensitive details, contact the maintainer privately through the GitHub profile.

## Examples of Security-Relevant Issues

- raw tokens appearing in logs
- passwords not being masked
- cookies or authorization headers leaking
- private keys or mnemonic phrases being stored
- exported logs containing raw secrets

## Supported Versions

- `debug_kit` 0.2.x
- official adapters 0.1.x

## Reminder

Use fake values in reports, for example:

```text
password is: my_fake_password_123
token=demo_token_abc123
```
