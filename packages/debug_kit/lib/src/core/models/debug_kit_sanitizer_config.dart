/// Configuration for DebugKit sanitization behavior.
///
/// The defaults keep DebugKit secure by masking sensitive values before they
/// reach the in-memory store, console mirroring, or export pipeline.
class DebugKitSanitizerConfig {
  /// Disables every sanitizer rule when set to `true`.
  ///
  /// This is a dangerous escape hatch for trusted local development sessions
  /// only. When enabled, raw values can reach the in-app console, Flutter /
  /// IDE console mirroring, and exported log files.
  final bool dangerouslyDisableSanitizer;

  /// Whether token-like values should be redacted.
  final bool redactTokens;

  /// Whether authorization header values should be redacted.
  final bool redactAuthorizationHeaders;

  /// Whether cookie values should be redacted.
  final bool redactCookies;

  /// Whether API-key-like values should be redacted.
  final bool redactApiKeys;

  /// Whether password-like values should be redacted.
  final bool redactPasswords;

  /// Whether private-key material should be redacted.
  final bool redactPrivateKeys;

  /// Whether mnemonic / seed phrase values should be redacted.
  final bool redactMnemonics;

  /// Creates a secure, production-usable sanitizer configuration.
  const DebugKitSanitizerConfig({
    this.dangerouslyDisableSanitizer = false,
    this.redactTokens = true,
    this.redactAuthorizationHeaders = true,
    this.redactCookies = true,
    this.redactApiKeys = true,
    this.redactPasswords = true,
    this.redactPrivateKeys = true,
    this.redactMnemonics = true,
  });

  /// Returns a copy of this config with selected fields replaced.
  DebugKitSanitizerConfig copyWith({
    bool? dangerouslyDisableSanitizer,
    bool? redactTokens,
    bool? redactAuthorizationHeaders,
    bool? redactCookies,
    bool? redactApiKeys,
    bool? redactPasswords,
    bool? redactPrivateKeys,
    bool? redactMnemonics,
  }) {
    return DebugKitSanitizerConfig(
      dangerouslyDisableSanitizer:
          dangerouslyDisableSanitizer ?? this.dangerouslyDisableSanitizer,
      redactTokens: redactTokens ?? this.redactTokens,
      redactAuthorizationHeaders:
          redactAuthorizationHeaders ?? this.redactAuthorizationHeaders,
      redactCookies: redactCookies ?? this.redactCookies,
      redactApiKeys: redactApiKeys ?? this.redactApiKeys,
      redactPasswords: redactPasswords ?? this.redactPasswords,
      redactPrivateKeys: redactPrivateKeys ?? this.redactPrivateKeys,
      redactMnemonics: redactMnemonics ?? this.redactMnemonics,
    );
  }
}
