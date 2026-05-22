class DebugLogSanitizer {
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

  static final RegExp _privateKeyPattern = RegExp(r'\b(0x)?[0-9a-fA-F]{64}\b');

  static String sanitizeMessage(String message) {
    var sanitized = message;

    // Redact private keys (Full redaction)
    sanitized = sanitized.replaceAllMapped(
        _privateKeyPattern, (match) => '[REDACTED PRIVATE KEY]');

    // Redact labeled mnemonics
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

    // Mask Bearer tokens
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

    // Mask inline patterns like token=value, password: value, or password is: value
    // We use a more conservative regex to avoid masking sentences like "Password screen opened"
    sanitized = sanitized.replaceAllMapped(
      RegExp(
          r'\b(token|password|secret|key|authorization|api_key)\b\s*(?:is\s*[:\s]|[:=])\s*([^\s,;\)]+)',
          caseSensitive: false),
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

  /// Smart masking for sensitive values.
  /// - Length <= 3: ***
  /// - Length 4 to 6: keep first 1, last 1, mask middle with *
  /// - Length 7 to 12: keep first 2, last 2, mask middle with *
  /// - Length >= 13: keep first 3, last 3, mask middle with *
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

  static bool _isSensitiveKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
    return _sensitiveKeys.any((k) {
      final normalizedK = k.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
      return normalizedKey.contains(normalizedK);
    });
  }

  static Map<String, String> sanitizeHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      if (_isSensitiveKey(key)) {
        return MapEntry(key, maskValue(value.toString()));
      }
      return MapEntry(key, value.toString());
    });
  }

  static Map<String, String>? sanitizeMetadata(Map<String, String>? metadata) {
    if (metadata == null) return null;
    return metadata.map((key, value) {
      if (_isSensitiveKey(key)) {
        return MapEntry(key, maskValue(value));
      }
      return MapEntry(key, value);
    });
  }

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

  static String? trimStackTrace(String? stackTrace, {int maxLines = 25}) {
    if (stackTrace == null) return null;
    final lines = stackTrace.split('\n');
    if (lines.length <= maxLines) return stackTrace;
    return '${lines.take(maxLines).join('\n')}\n... (${lines.length - maxLines} lines trimmed)';
  }
}
