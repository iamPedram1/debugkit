import 'dart:async';
import 'dart:convert';

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
    try {
      final uri = Uri.parse(url);
      return DebugLogSanitizer.sanitizeUri(uri);
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
    return DebugLogSanitizer.sanitizeHeaders(headers);
  }

  /// Extracts allowlisted backend correlation IDs from response headers.
  ///
  /// Only captures the first non-empty value for each supported key and
  /// truncates the sanitized value to 64 characters.
  static Map<String, String> extractBackendCorrelationHeaders(
    Map<String, List<String>> headers,
  ) {
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

        final sanitized = DebugLogSanitizer.sanitizeMessage(value.trim());
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
  }) {
    if (!captureHeaders || headers.isEmpty) return null;
    final sanitized = DebugLogSanitizer.sanitizeHeaders(headers);
    return _buildPreview(sanitized, maxPreviewChars: maxPreviewChars);
  }

  /// Builds a sanitized response-header preview using a safe allowlist.
  static String? buildResponseHeadersPreview(
    Map<String, List<String>> headers, {
    required bool captureHeaders,
    int maxPreviewChars = 1000,
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
      selected[key] = DebugLogSanitizer.sanitizeMessage(value.trim());
    });

    if (selected.isEmpty) return null;
    return _buildPreview(selected, maxPreviewChars: maxPreviewChars);
  }

  /// Builds a sanitized body preview for opt-in capture.
  static String? buildBodyPreview(
    dynamic body, {
    required bool captureBody,
    required int maxCaptureBytes,
    required int maxPreviewChars,
  }) {
    if (!captureBody || body == null) return null;

    if (body is FormData || body is MultipartFile || body is Stream) {
      return null;
    }
    if (body is List<int>) {
      return null;
    }

    String? preview;
    if (body is String) {
      preview = body;
    } else if (body is Map || body is List || body is num || body is bool) {
      try {
        preview = jsonEncode(DebugLogSanitizer.sanitizePayload(body));
      } catch (_) {
        preview = body.toString();
      }
    } else {
      preview = body.toString();
    }

    if (preview.isEmpty) return null;
    final previewText = preview;
    if (previewText.length > maxCaptureBytes) return null;

    final sanitized = DebugLogSanitizer.sanitizeMessage(previewText);
    if (sanitized.length > maxPreviewChars) {
      return '${sanitized.substring(0, maxPreviewChars)}…';
    }
    return sanitized;
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
