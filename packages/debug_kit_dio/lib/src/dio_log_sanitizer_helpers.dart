import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;

import 'package:debug_kit/debug_kit.dart';
import 'package:dio/dio.dart';

/// Internal sanitization helpers for Dio-specific data.
///
/// Thin wrappers around the DebugKit core [DebugLogSanitizer] that handle the
/// Dio-specific types (raw header maps, URL strings) before they reach the
/// core logging path.
///
/// Not part of the public adapter API — used only by [DebugKitDioInterceptor].
class DioLogSanitizerHelpers {
  static const Set<String> _safeResponseHeaderAllowlist = {
    'content-type',
    'content-length',
    'cache-control',
    'etag',
    'last-modified',
    'date',
    'server',
    'x-request-id',
    'request-id',
    'x-correlation-id',
    'x-trace-id',
    'trace-id',
  };

  /// Parses [url] into a [Uri] and masks sensitive query parameter values.
  ///
  /// Delegates to [DebugLogSanitizer.sanitizeUri]. Returns [url] unchanged if
  /// parsing fails (malformed URL).
  ///
  /// Example: `https://api.example.com/users?token=secret` →
  /// `https://api.example.com/users?token=se*****et`
  static String sanitizeUrl(String url) {
    return sanitizeUrlWithConfig(url);
  }

  static String sanitizeUrlWithConfig(
    String url, {
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    try {
      final uri = Uri.parse(url);
      return DebugLogSanitizer.sanitizeUri(uri, config: config);
    } catch (_) {
      return url;
    }
  }

  /// Sanitizes a Dio header map by masking values for sensitive header names.
  ///
  /// Accepts `Map<String, dynamic>` as returned by Dio's [RequestOptions.headers]
  /// and delegates to [DebugLogSanitizer.sanitizeHeaders].
  ///
  /// Common headers that are masked:
  /// - `Authorization`, `Cookie`, `Set-Cookie`
  /// - `X-Auth-Token`, `X-Api-Key`
  static Map<String, String> sanitizeHeaders(Map<String, dynamic> headers) {
    return sanitizeHeadersWithConfig(headers);
  }

  static Map<String, String> sanitizeHeadersWithConfig(
    Map<String, dynamic> headers, {
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    return DebugLogSanitizer.sanitizeHeaders(headers, config: config);
  }

  /// Extracts allowlisted backend correlation IDs from response headers.
  ///
  /// Only captures the first non-empty value for each supported key and
  /// truncates the sanitized value to 64 characters.
  static Map<String, String> extractBackendCorrelationHeaders(
    Map<String, List<String>> headers, {
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    final result = <String, String>{};

    void capture(
      List<String> names,
      String metadataKey,
    ) {
      for (final name in names) {
        final values = headers[name] ?? headers[name.toLowerCase()];
        final value = values == null
            ? null
            : values.cast<String?>().firstWhere(
                  (v) => v != null && v.trim().isNotEmpty,
                  orElse: () => null,
                );
        if (value == null || value.trim().isEmpty) continue;

        final sanitized =
            DebugLogSanitizer.sanitizeMessage(value.trim(), config: config);
        result[metadataKey] =
            sanitized.length > 64 ? sanitized.substring(0, 64) : sanitized;
        return;
      }
    }

    capture(['x-request-id', 'request-id'], 'backendRequestId');
    capture(['x-correlation-id'], 'backendCorrelationId');
    capture(['x-trace-id', 'trace-id'], 'backendTraceId');

    return result;
  }

  /// Builds a sanitized request-header preview string.
  ///
  /// Returns `null` when [captureHeaders] is `false` or the preview is empty.
  static String? buildRequestHeadersPreview(
    Map<String, dynamic> headers, {
    required bool captureHeaders,
    int maxPreviewChars = 1000,
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    if (!captureHeaders || headers.isEmpty) return null;
    final sanitized =
        DebugLogSanitizer.sanitizeHeaders(headers, config: config);
    return _buildPreview(sanitized, maxPreviewChars: maxPreviewChars);
  }

  /// Builds a sanitized response-header preview using a safe allowlist.
  static String? buildResponseHeadersPreview(
    Map<String, List<String>> headers, {
    required bool captureHeaders,
    int maxPreviewChars = 1000,
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    if (!captureHeaders || headers.isEmpty) return null;

    final selected = <String, String>{};
    headers.forEach((key, values) {
      if (!_safeResponseHeaderAllowlist.contains(key.toLowerCase())) {
        return;
      }
      final value = values.cast<String?>().firstWhere(
            (v) => v != null && v.trim().isNotEmpty,
            orElse: () => null,
          );
      if (value == null) return;
      selected[key] =
          DebugLogSanitizer.sanitizeMessage(value.trim(), config: config);
    });

    if (selected.isEmpty) return null;
    return _buildPreview(selected, maxPreviewChars: maxPreviewChars);
  }

  /// Builds a sanitized body preview for opt-in capture.
  static ({String? preview, String? skipReason}) buildBodyPreview(
    dynamic body, {
    required bool captureBody,
    required bool prettyPrintJson,
    required bool decodeGzipBodies,
    required int maxBodyBytes,
    required int maxPreviewChars,
    String? contentType,
    String? contentEncoding,
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    if (!captureBody || body == null) {
      return (preview: null, skipReason: 'body capture disabled');
    }

    if (body is FormData || body is MultipartFile || body is Stream) {
      return (preview: null, skipReason: 'multipart or streamed payload');
    }
    if (body is List<int>) {
      return _previewFromBytes(
        body,
        captureBody: captureBody,
        prettyPrintJson: prettyPrintJson,
        decodeGzipBodies: decodeGzipBodies,
        maxBodyBytes: maxBodyBytes,
        maxPreviewChars: maxPreviewChars,
        contentType: contentType,
        contentEncoding: contentEncoding,
        config: config,
      );
    }

    late final String previewText;
    if (body is String) {
      previewText = body;
    } else if (body is Map || body is List || body is num || body is bool) {
      try {
        final sanitized =
            DebugLogSanitizer.sanitizePayload(body, config: config);
        previewText = prettyPrintJson
            ? const JsonEncoder.withIndent('  ').convert(sanitized)
            : jsonEncode(sanitized);
      } catch (_) {
        previewText = body.toString();
      }
    } else {
      previewText = body.toString();
    }

    if (previewText.length > maxBodyBytes) {
      return (preview: null, skipReason: 'body exceeds $maxBodyBytes bytes');
    }

    return _buildTextPreview(
      previewText,
      prettyPrintJson: prettyPrintJson,
      maxPreviewChars: maxPreviewChars,
      config: config,
    );
  }

  static ({String? preview, String? skipReason}) _previewFromBytes(
    List<int> bytes, {
    required bool captureBody,
    required bool prettyPrintJson,
    required bool decodeGzipBodies,
    required int maxBodyBytes,
    required int maxPreviewChars,
    String? contentType,
    String? contentEncoding,
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    if (bytes.length > maxBodyBytes) {
      return (preview: null, skipReason: 'body exceeds $maxBodyBytes bytes');
    }

    final decoded = _decodeBytes(
      bytes,
      decodeGzipBodies: decodeGzipBodies,
      contentEncoding: contentEncoding,
    );
    if (decoded == null) {
      return (
        preview: null,
        skipReason: decodeGzipBodies
            ? 'binary payload or gzip body could not be decoded'
            : 'binary payload',
      );
    }

    return _buildTextPreview(
      decoded,
      prettyPrintJson: prettyPrintJson,
      maxPreviewChars: maxPreviewChars,
      config: config,
    );
  }

  static String? _decodeBytes(
    List<int> bytes, {
    required bool decodeGzipBodies,
    String? contentEncoding,
  }) {
    var working = bytes;
    final encoding = contentEncoding?.toLowerCase() ?? '';
    final looksGzip = encoding.contains('gzip') ||
        (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b);
    if (decodeGzipBodies && looksGzip) {
      try {
        working = gzip.decode(bytes);
      } catch (_) {
        return null;
      }
    }

    try {
      return utf8.decode(working);
    } catch (_) {
      return null;
    }
  }

  static ({String? preview, String? skipReason}) _buildTextPreview(
    String text, {
    required bool prettyPrintJson,
    required int maxPreviewChars,
    DebugKitSanitizerConfig config = const DebugKitSanitizerConfig(),
  }) {
    final normalized = _maybePrettyPrintJson(
      text,
      prettyPrintJson: prettyPrintJson,
    );

    if (normalized.isEmpty) {
      return (preview: null, skipReason: 'empty body');
    }

    final sanitized = DebugLogSanitizer.sanitizeMessage(
      normalized,
      config: config,
    );
    if (sanitized.length > maxPreviewChars) {
      return (
        preview: '${sanitized.substring(0, maxPreviewChars)}…',
        skipReason: null,
      );
    }
    return (preview: sanitized, skipReason: null);
  }

  static String _maybePrettyPrintJson(
    String text, {
    required bool prettyPrintJson,
  }) {
    if (!prettyPrintJson) return text;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return text;

    try {
      final decoded = jsonDecode(trimmed);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return text;
    }
  }

  static String _buildPreview(
    Map<String, String> headers, {
    required int maxPreviewChars,
  }) {
    final entries = headers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final preview = entries.map((e) => '${e.key}: ${e.value}').join('\n');
    if (preview.length <= maxPreviewChars) return preview;
    return '${preview.substring(0, maxPreviewChars)}…';
  }
}
