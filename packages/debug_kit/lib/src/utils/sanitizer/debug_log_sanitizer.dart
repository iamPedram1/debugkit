import '../../core/models/debug_kit_sanitizer_config.dart';

/// Stateless sanitization utilities used throughout DebugKit.
///
/// All public methods are pure. They take an input value, return a sanitized
/// copy, and never mutate state. Callers are expected to pass sanitized data
/// into the store unless `dangerouslyDisableSanitizer` is intentionally
/// enabled for trusted local debugging.
class DebugLogSanitizer {
  static const _redactedPrivateKey = '[REDACTED PRIVATE KEY]';
  static const _redactedMnemonic = '[REDACTED MNEMONIC]';

  static final RegExp _privateKeyPemPattern = RegExp(
    r'-----BEGIN (?:RSA |EC )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC )?PRIVATE KEY-----',
    caseSensitive: false,
  );

  static final RegExp _mnemonicPattern = RegExp(
    r'\b(mnemonic|seed\s*phrase|recovery\s*phrase)\b\s*(?:is\s*[:\s]|[:=])\s*([a-z]{3,}(?:\s+[a-z]{3,}){11,23})\b',
    caseSensitive: false,
  );

  static final RegExp _authorizationPattern = RegExp(
    r'\b(Authorization|Proxy-Authorization)\b\s*(?:is\s*[:\s]|[:=])\s*([^\r\n]+)',
    caseSensitive: false,
  );

  static final RegExp _cookiePattern = RegExp(
    r'\b(Set-Cookie|Cookie)\b\s*(?:is\s*[:\s]|[:=])\s*([^\r\n]+)',
    caseSensitive: false,
  );

  static final RegExp _tokenPattern = RegExp(
    r'\b(token|access[_-]?token|refresh[_-]?token|id[_-]?token)\b\s*(?:is\s*[:\s]|[:=])\s*([^\s,;\)]+)',
    caseSensitive: false,
  );

  static final RegExp _bearerPattern = RegExp(
    r'\b(Bearer)\b\s+([^\s,;]+)',
    caseSensitive: false,
  );

  static final RegExp _passwordPattern = RegExp(
    r'\b(password|passwd|secret)\b\s*(?:is\s*[:\s]|[:=])\s*([^\s,;\)]+)',
    caseSensitive: false,
  );

  static final RegExp _apiKeyPattern = RegExp(
    r'\b(api[_-]?key|x[_-]?api[_-]?key|client[_-]?secret)\b\s*(?:is\s*[:\s]|[:=])\s*([^\s,;\)]+)',
    caseSensitive: false,
  );

  static const Set<String> _tokenKeys = {
    'token',
    'accesstoken',
    'refreshtoken',
    'idtoken',
  };

  static const Set<String> _authorizationKeys = {
    'authorization',
    'proxyauthorization',
  };

  static const Set<String> _cookieKeys = {
    'cookie',
    'setcookie',
  };

  static const Set<String> _apiKeyKeys = {
    'apikey',
    'xapikey',
    'clientsecret',
  };

  static const Set<String> _passwordKeys = {
    'password',
    'passwd',
    'secret',
  };

  static const Set<String> _privateKeyKeys = {
    'privatekey',
  };

  static const Set<String> _mnemonicKeys = {
    'mnemonic',
    'seedphrase',
    'recoveryphrase',
  };

  /// Scans [message] for inline secrets and returns a sanitized copy.
  static String sanitizeMessage(
    String message, {
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    if (config.dangerouslyDisableSanitizer) return message;

    var sanitized = message;
    final shields = <String, String>{};

    if (!config.redactAuthorizationHeaders) {
      sanitized = _shieldMatches(sanitized, _authorizationPattern, shields);
    }
    if (!config.redactCookies) {
      sanitized = _shieldMatches(sanitized, _cookiePattern, shields);
    }

    if (config.redactPrivateKeys) {
      sanitized = sanitized.replaceAllMapped(
        _privateKeyPemPattern,
        (_) => _redactedPrivateKey,
      );
    }

    if (config.redactMnemonics) {
      sanitized = sanitized.replaceAllMapped(_mnemonicPattern, (match) {
        final key = match.group(1)!;
        final separator = match.group(0)!.substring(
              key.length,
              match.group(0)!.length - match.group(2)!.length,
            );
        return '$key$separator$_redactedMnemonic';
      });
    }

    if (config.redactAuthorizationHeaders) {
      sanitized = sanitized.replaceAllMapped(_authorizationPattern, (match) {
        final key = match.group(1)!;
        final separator = match.group(0)!.substring(
              key.length,
              match.group(0)!.length - match.group(2)!.length,
            );
        return '$key$separator${maskValue(match.group(2)!)}';
      });
    }

    if (config.redactCookies) {
      sanitized = sanitized.replaceAllMapped(_cookiePattern, (match) {
        final key = match.group(1)!;
        final separator = match.group(0)!.substring(
              key.length,
              match.group(0)!.length - match.group(2)!.length,
            );
        return '$key$separator${maskValue(match.group(2)!)}';
      });
    }

    if (config.redactTokens) {
      sanitized = sanitized.replaceAllMapped(_tokenPattern, (match) {
        final key = match.group(1)!;
        final separator = match.group(0)!.substring(
              key.length,
              match.group(0)!.length - match.group(2)!.length,
            );
        return '$key$separator${maskValue(match.group(2)!)}';
      });
      sanitized = sanitized.replaceAllMapped(_bearerPattern, (match) {
        final prefix = match.group(1)!;
        return '$prefix ${maskValue(match.group(2)!)}';
      });
    }

    if (config.redactPasswords) {
      sanitized = sanitized.replaceAllMapped(_passwordPattern, (match) {
        final key = match.group(1)!;
        final separator = match.group(0)!.substring(
              key.length,
              match.group(0)!.length - match.group(2)!.length,
            );
        return '$key$separator${maskValue(match.group(2)!)}';
      });
    }

    if (config.redactApiKeys) {
      sanitized = sanitized.replaceAllMapped(_apiKeyPattern, (match) {
        final key = match.group(1)!;
        final separator = match.group(0)!.substring(
              key.length,
              match.group(0)!.length - match.group(2)!.length,
            );
        return '$key$separator${maskValue(match.group(2)!)}';
      });
    }

    return _restoreShields(sanitized, shields);
  }

  /// Returns a partially masked copy of [value].
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

  /// Recursively sanitizes a JSON-like [payload] map.
  static Map<String, dynamic>? sanitizePayload(
    dynamic payload, {
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    if (config.dangerouslyDisableSanitizer) {
      if (payload == null) return null;
      if (payload is! Map<String, dynamic>) {
        if (payload is List) {
          return {'list': payload};
        }
        return {'value': payload};
      }
      return payload;
    }

    if (payload == null) return null;
    if (payload is! Map<String, dynamic>) {
      if (payload is List) {
        return {
          'list': payload.map((e) => _sanitizeValue(null, e, config)).toList(),
        };
      }
      return {'value': _sanitizeValue(null, payload, config)};
    }

    return payload.map(
      (key, value) => MapEntry(key, _sanitizeValue(key, value, config)),
    );
  }

  static dynamic _sanitizeValue(
    String? key,
    dynamic value,
    DebugKitSanitizerConfig config,
  ) {
    if (value == null) return null;

    if (key != null && _isSensitiveKey(key, config)) {
      if (_isPrivateKeyKey(key) && value is String) {
        if (_privateKeyPemPattern.hasMatch(value)) {
          return _redactedPrivateKey;
        }
        return value;
      }
      return maskValue(value.toString());
    }

    if (value is Map<String, dynamic>) {
      return sanitizePayload(value, config: config);
    }

    if (value is List) {
      return value.map((e) => _sanitizeValue(key, e, config)).toList();
    }

    if (value is String) {
      return sanitizeMessage(value, config: config);
    }

    return value;
  }

  static bool _isSensitiveKey(String key, DebugKitSanitizerConfig config) {
    final normalizedKey = _normalizeKey(key);
    return (_tokenKeys.any(normalizedKey.contains) && config.redactTokens) ||
        (_authorizationKeys.any(normalizedKey.contains) &&
            config.redactAuthorizationHeaders) ||
        (_cookieKeys.any(normalizedKey.contains) && config.redactCookies) ||
        (_apiKeyKeys.any(normalizedKey.contains) && config.redactApiKeys) ||
        (_passwordKeys.any(normalizedKey.contains) && config.redactPasswords) ||
        (_privateKeyKeys.any(normalizedKey.contains) &&
            config.redactPrivateKeys) ||
        (_mnemonicKeys.any(normalizedKey.contains) && config.redactMnemonics);
  }

  static bool _isPrivateKeyKey(String key) {
    final normalized = _normalizeKey(key);
    return _privateKeyKeys.any(normalized.contains);
  }

  static String _normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
  }

  /// Sanitizes HTTP headers, masking values for sensitive header names.
  static Map<String, String> sanitizeHeaders(
    Map<String, dynamic> headers, {
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    if (config.dangerouslyDisableSanitizer) {
      return headers.map((key, value) => MapEntry(key, value.toString()));
    }
    return headers.map((key, value) {
      if (_isSensitiveKey(key, config)) {
        if (_isPrivateKeyKey(key) && value is String) {
          return MapEntry(
            key,
            _privateKeyPemPattern.hasMatch(value) ? _redactedPrivateKey : value,
          );
        }
        return MapEntry(key, maskValue(value.toString()));
      }
      return MapEntry(key, value.toString());
    });
  }

  /// Sanitizes a `Map<String, String>` metadata map.
  static Map<String, String>? sanitizeMetadata(
    Map<String, String>? metadata, {
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    if (metadata == null) return null;
    if (config.dangerouslyDisableSanitizer) return metadata;

    return metadata.map((key, value) {
      if (_isSensitiveKey(key, config)) {
        if (_isPrivateKeyKey(key) && _privateKeyPemPattern.hasMatch(value)) {
          return MapEntry(key, _redactedPrivateKey);
        }
        return MapEntry(key, maskValue(value));
      }
      return MapEntry(key, value);
    });
  }

  /// Sanitizes a [Uri] by masking sensitive query parameter values.
  static String sanitizeUri(
    Uri uri, {
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    if (config.dangerouslyDisableSanitizer) return uri.toString();
    if (uri.queryParameters.isEmpty) return uri.toString();

    final sanitizedParams = uri.queryParameters.map((key, value) {
      if (_isSensitiveKey(key, config)) {
        if (_isPrivateKeyKey(key) && _privateKeyPemPattern.hasMatch(value)) {
          return MapEntry(key, _redactedPrivateKey);
        }
        return MapEntry(key, maskValue(value));
      }
      return MapEntry(key, value);
    });

    return uri.replace(queryParameters: sanitizedParams).toString();
  }

  /// Trims [stackTrace] to at most [maxLines] lines.
  static String? trimStackTrace(
    String? stackTrace, {
    int maxLines = 25,
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    if (stackTrace == null) return null;
    if (config.dangerouslyDisableSanitizer) return stackTrace;
    final lines = stackTrace.split('\n');
    if (lines.length <= maxLines) return stackTrace;
    return '${lines.take(maxLines).join('\n')}\n... (${lines.length - maxLines} lines trimmed)';
  }

  static String _shieldMatches(
    String input,
    RegExp pattern,
    Map<String, String> shields,
  ) {
    var counter = shields.length;
    return input.replaceAllMapped(pattern, (match) {
      final placeholder = '[[DEBUGKIT_SHIELD_${counter++}]]';
      shields[placeholder] = match.group(0)!;
      return placeholder;
    });
  }

  static String _restoreShields(String input, Map<String, String> shields) {
    var output = input;
    shields.forEach((placeholder, original) {
      output = output.replaceAll(placeholder, original);
    });
    return output;
  }
}
