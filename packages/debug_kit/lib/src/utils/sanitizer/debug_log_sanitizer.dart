/// Stateless sanitization utilities used throughout DebugKit.
///
/// All public methods are pure — they take a value, return a sanitized copy,
/// and never mutate state. They are called by [DebugKitController.log] before
/// any data reaches the in-memory store, so exported logs always contain only
/// already-sanitized content.
///
/// **Sanitization strategy:**
/// - **Full redaction**: 64-character hex strings (private keys) are replaced
///   with `[REDACTED PRIVATE KEY]`. Labeled mnemonic phrases are replaced with
///   `[REDACTED MNEMONIC]`.
/// - **Smart masking**: all other sensitive values are partially masked using
///   [maskValue], which preserves a few characters at the start and end for
///   context while obscuring the middle.
/// - **Key-based masking**: metadata and header keys matching known sensitive
///   patterns (e.g. `api_key`, `authorization`, `token`) have their values
///   masked regardless of the value content.
/// - **Natural-language masking**: inline patterns like `token=abc`,
///   `password: abc`, and `Bearer abc` in free-form message strings are
///   detected and masked.
class DebugLogSanitizer {
  /// Set of known sensitive metadata / header key patterns.
  ///
  /// Compared after normalizing to lowercase with hyphens and underscores
  /// stripped, so `'X-Auth-Token'`, `'x_auth_token'`, and `'xauthtoken'`
  /// all match.
  static const Set<String> _sensitiveKeys = {
    'password',
    'token',
    'accessToken',
    'refreshToken',
    'access_token',
    'refresh_token',
    'id_token',
    'idToken',
    'secret',
    'client_secret',
    'authorization',
    'api_key',
    'apiKey',
    'privateKey',
    'private_key',
    'mnemonic',
    'seedPhrase',
    'seed_phrase',
    'cookie',
    'set-cookie',
    'x-auth-token',
    'x-api-key',
  };

  /// Regex that matches a 64-character hex string (with or without `0x` prefix).
  ///
  /// This pattern covers Ethereum / EVM private keys and similar secrets.
  static final RegExp _privateKeyPattern = RegExp(r'\b(0x)?[0-9a-fA-F]{64}\b');

  // ---------------------------------------------------------------------------
  // Message sanitization
  // ---------------------------------------------------------------------------

  /// Scans [message] for inline secrets and returns a sanitized copy.
  ///
  /// Performed in order:
  /// 1. Full-redact 64-char hex strings → `[REDACTED PRIVATE KEY]`.
  /// 2. Full-redact labeled mnemonic / seed phrases → `[REDACTED MNEMONIC]`.
  /// 3. Smart-mask `Bearer <token>` values.
  /// 4. Smart-mask `key=value`, `key: value`, and `key is: value` patterns
  ///    where the key matches a known sensitive keyword.
  ///
  /// Conservative: harmless sentences like `"Password screen opened"` are not
  /// masked because they don't contain a separator (`=`, `:`, `is:`).
  static String sanitizeMessage(String message) {
    var sanitized = message;

    // 1. Full redaction — private keys
    sanitized = sanitized.replaceAllMapped(
        _privateKeyPattern, (match) => '[REDACTED PRIVATE KEY]');

    // 2. Full redaction — labeled mnemonic phrases
    sanitized = sanitized.replaceAllMapped(
      RegExp(
        r'\b(mnemonic|seed\s*phrase|recovery\s*phrase)\b\s*(?:is\s*[:\s]|[:=])\s*([a-z]{3,}(?:\s+[a-z]{3,}){11,23})\b',
        caseSensitive: false,
      ),
      (match) {
        final key = match.group(1)!;
        final separator = match.group(0)!.substring(
            key.length, match.group(0)!.length - match.group(2)!.length);
        return '$key$separator[REDACTED MNEMONIC]';
      },
    );

    // 3. Smart-mask Bearer tokens
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b(Bearer)\b\s+([^\s,;]+)', caseSensitive: false),
      (match) {
        final prefix = match.group(1);
        final value = match.group(2);
        if (value == null || value.startsWith('[REDACTED')) {
          return match.group(0)!;
        }
        return '$prefix ${maskValue(value)}';
      },
    );

    // 4. Smart-mask inline key=value / key: value / key is: value patterns
    sanitized = sanitized.replaceAllMapped(
      RegExp(
        r'\b(token|password|secret|key|authorization|api_key)\b\s*(?:is\s*[:\s]|[:=])\s*([^\s,;\)]+)',
        caseSensitive: false,
      ),
      (match) {
        final key = match.group(1);
        final separator = match.group(0)!.substring(
            key!.length, match.group(0)!.length - match.group(2)!.length);
        final value = match.group(2);
        if (value == null || value.startsWith('[REDACTED')) {
          return match.group(0)!;
        }
        return '$key$separator${maskValue(value)}';
      },
    );

    return sanitized;
  }

  // ---------------------------------------------------------------------------
  // Value masking
  // ---------------------------------------------------------------------------

  /// Returns a partially masked copy of [value].
  ///
  /// The masking strategy preserves context at the edges while hiding the
  /// sensitive middle portion:
  ///
  /// | Length  | Strategy                     | Example (`abc123secret`) |
  /// |---------|------------------------------|--------------------------|
  /// | ≤ 3     | Fully masked: `***`          | `abc` → `***`            |
  /// | 4–6     | Keep 1 start, 1 end          | `abcde` → `a***e`        |
  /// | 7–12    | Keep 2 start, 2 end          | `abc123secret` → `ab...et` |
  /// | ≥ 13    | Keep 3 start, 3 end          | `my_secret_key_123` → `my_...123` |
  ///
  /// Empty strings are returned unchanged.
  static String maskValue(String value) {
    if (value.isEmpty) return value;
    final len = value.length;

    if (len <= 3) {
      return '***';
    }

    int startCount;
    int endCount;

    if (len <= 6) {
      startCount = 1;
      endCount = 1;
    } else if (len <= 12) {
      startCount = 2;
      endCount = 2;
    } else {
      startCount = 3;
      endCount = 3;
    }

    final middleCount = len - startCount - endCount;
    if (middleCount <= 0) return '***';

    final start = value.substring(0, startCount);
    final end = value.substring(len - endCount);
    final maskedMiddle = '*' * middleCount;

    return '$start$maskedMiddle$end';
  }

  // ---------------------------------------------------------------------------
  // Structured data sanitization
  // ---------------------------------------------------------------------------

  /// Recursively sanitizes a JSON-like [payload] map.
  ///
  /// - Keys matching [_sensitiveKeys] have their values replaced with
  ///   [maskValue].
  /// - String values are passed through [sanitizeMessage].
  /// - Nested maps and lists are sanitized recursively.
  /// - Non-map, non-list, non-string values are returned as-is.
  ///
  /// Returns `null` when [payload] is `null`.
  static Map<String, dynamic>? sanitizePayload(dynamic payload) {
    if (payload == null) return null;
    if (payload is! Map<String, dynamic>) {
      if (payload is List) {
        return {'list': payload.map((e) => _sanitizeValue(null, e)).toList()};
      }
      return {'value': _sanitizeValue(null, payload)};
    }

    return payload
        .map((key, value) => MapEntry(key, _sanitizeValue(key, value)));
  }

  static dynamic _sanitizeValue(String? key, dynamic value) {
    if (value == null) return null;

    if (key != null && _isSensitiveKey(key)) {
      return maskValue(value.toString());
    }

    if (value is Map<String, dynamic>) {
      return sanitizePayload(value);
    }

    if (value is List) {
      return value.map((e) => _sanitizeValue(key, e)).toList();
    }

    if (value is String) {
      return sanitizeMessage(value);
    }

    return value;
  }

  /// Returns `true` if [key] matches any known sensitive key pattern.
  ///
  /// Comparison is case-insensitive and ignores hyphens and underscores.
  static bool _isSensitiveKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
    return _sensitiveKeys.any((k) {
      final normalizedK = k.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
      return normalizedKey.contains(normalizedK);
    });
  }

  /// Sanitizes HTTP headers, masking values for sensitive header names.
  ///
  /// Common examples that are masked:
  /// - `Authorization`, `Cookie`, `Set-Cookie`
  /// - `X-Auth-Token`, `X-Api-Key`
  ///
  /// All values are converted to strings via `.toString()`.
  static Map<String, String> sanitizeHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      if (_isSensitiveKey(key)) {
        return MapEntry(key, maskValue(value.toString()));
      }
      return MapEntry(key, value.toString());
    });
  }

  /// Sanitizes a `Map<String, String>` metadata map.
  ///
  /// Keys matching sensitive patterns have their values replaced with
  /// [maskValue]. Non-sensitive values are returned unchanged.
  ///
  /// Returns `null` when [metadata] is `null`.
  static Map<String, String>? sanitizeMetadata(Map<String, String>? metadata) {
    if (metadata == null) return null;
    return metadata.map((key, value) {
      if (_isSensitiveKey(key)) {
        return MapEntry(key, maskValue(value));
      }
      return MapEntry(key, value);
    });
  }

  /// Sanitizes a [Uri] by masking sensitive query parameter values.
  ///
  /// The scheme, host, path, and non-sensitive parameters are preserved.
  /// Returns the original [uri] string unchanged when there are no query
  /// parameters.
  static String sanitizeUri(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri.toString();

    final sanitizedParams = uri.queryParameters.map((key, value) {
      if (_isSensitiveKey(key)) {
        return MapEntry(key, maskValue(value));
      }
      return MapEntry(key, value);
    });

    return uri.replace(queryParameters: sanitizedParams).toString();
  }

  /// Trims [stackTrace] to at most [maxLines] lines.
  ///
  /// Appends a `'... (N lines trimmed)'` note when trimming occurs.
  /// Returns `null` when [stackTrace] is `null`.
  ///
  /// Defaults to 25 lines, which is enough context for most debugging without
  /// flooding the export file.
  static String? trimStackTrace(String? stackTrace, {int maxLines = 25}) {
    if (stackTrace == null) return null;
    final lines = stackTrace.split('\n');
    if (lines.length <= maxLines) return stackTrace;
    return '${lines.take(maxLines).join('\n')}\n... (${lines.length - maxLines} lines trimmed)';
  }
}
