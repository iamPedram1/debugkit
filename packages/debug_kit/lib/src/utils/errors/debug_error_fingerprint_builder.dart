import '../../core/models/debug_log_entry.dart';
import '../../core/models/debug_log_source.dart';
import '../../core/models/debug_trace.dart';

/// Builds stable, collision-resistant fingerprints for grouping similar errors
/// into [DebugErrorDigestEntry] instances.
///
/// The fingerprint is designed to:
/// - **Group** repeated occurrences of the same error class together.
/// - **Keep separate** errors of different types, HTTP status codes, or
///   provider names — even when their messages share keywords.
/// - **Ignore** volatile values that change per call: timestamps, IDs, memory
///   addresses, request durations, and random UUID-like tokens.
///
/// This class is pure and stateless — all methods are `static`.
class DebugErrorFingerprintBuilder {
  DebugErrorFingerprintBuilder._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Builds a fingerprint for a [DebugLogEntry] that represents an error.
  ///
  /// Strategy (in priority order):
  /// 1. **Dio network errors** (`source == DebugLogSource.dio`): fingerprint
  ///    uses `method|path|statusCode`. Different status codes stay separate.
  /// 2. **Riverpod provider failures** (`source == DebugLogSource.riverpod`):
  ///    fingerprint uses `provider_name` from metadata + error type prefix.
  /// 3. **App / trace errors**: fingerprint uses error type prefix + normalized
  ///    message + first useful stack frame.
  ///
  /// Returns a stable string suitable as a map key.
  static String forLogEntry(DebugLogEntry entry) {
    if (entry.source == DebugLogSource.dio) {
      return _fingerprintForDioEntry(entry);
    }

    if (entry.source == DebugLogSource.riverpod) {
      return _fingerprintForRiverpodEntry(entry);
    }

    // Generic app / router error
    return _fingerprintForGenericEntry(entry);
  }

  /// Builds a fingerprint for a failed [DebugTrace].
  ///
  /// Uses the trace name + sanitized error summary.
  static String forFailedTrace(DebugTrace trace) {
    final normalizedError = trace.errorSummary != null
        ? _normalizeMessage(trace.errorSummary!)
        : '';
    return 'trace|${trace.name}|$normalizedError';
  }

  /// Normalizes an error message by stripping volatile values.
  ///
  /// Removed patterns:
  /// - Numbers (durations, IDs, status codes embedded in free text)
  /// - UUIDs / hex strings
  /// - Memory address-like patterns (`0x...`)
  /// - Path variables: `/users/123` → `/users/{id}`
  ///
  /// Conservative — does not strip letters or meaningful keywords.
  static String normalizeMessage(String message) {
    return _normalizeMessage(message);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static String _fingerprintForDioEntry(DebugLogEntry entry) {
    // Extract method and path from the log message (format: "METHOD url · STATUS · Nms")
    final method = _extractDioMethod(entry.message);
    final path = _extractDioPath(entry.message);
    final statusCode = _extractDioStatus(entry.message, entry.metadata);

    // Different HTTP methods, paths, or status codes are distinct errors.
    return 'dio|$method|$path|$statusCode';
  }

  static String _fingerprintForRiverpodEntry(DebugLogEntry entry) {
    final providerName = entry.metadata?['provider_name'] ?? '';
    // Extract error type prefix (before the first colon)
    final errorTypePrefix =
        _extractErrorTypePrefix(entry.error ?? entry.message);
    return 'riverpod|$providerName|$errorTypePrefix';
  }

  static String _fingerprintForGenericEntry(DebugLogEntry entry) {
    final errorTypePrefix =
        _extractErrorTypePrefix(entry.error ?? entry.message);
    final normalized = _normalizeMessage(entry.error ?? entry.message);
    final frame = _extractFirstUsefulFrame(entry.stackTrace);
    final source = entry.source.name;
    return 'app|$source|$errorTypePrefix|$normalized|${frame ?? ''}';
  }

  /// Extracts the HTTP method from a Dio log message like "GET /api · 401 · 120ms".
  static String _extractDioMethod(String message) {
    final parts = message.trim().split(' ');
    if (parts.isNotEmpty) {
      final candidate = parts.first.toUpperCase();
      const methods = {
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
        'HEAD',
        'OPTIONS'
      };
      if (methods.contains(candidate)) return candidate;
    }
    return '';
  }

  /// Extracts the URL path from a Dio log message, dropping query parameters.
  ///
  /// Example: `"GET https://api.example.com/users?token=se***et · 200 · 42ms"`
  /// → `"/users"`
  static String _extractDioPath(String message) {
    // Split on bullet separator and extract first token after method
    final parts = message.split('·');
    if (parts.isEmpty) return '';

    final firstPart = parts.first.trim();
    final tokens = firstPart.split(' ');
    if (tokens.length < 2) return '';

    final rawUrl = tokens.last.trim();
    try {
      final uri = Uri.parse(rawUrl);
      // Keep only path, strip query params and fragments
      return _normalizePath(uri.path);
    } catch (_) {
      return rawUrl;
    }
  }

  /// Normalizes path segments that look like IDs into `{id}` placeholders.
  ///
  /// Examples:
  /// - `/users/42` → `/users/{id}`
  /// - `/orders/abc-123-def` → `/orders/{id}`
  static String _normalizePath(String path) {
    return path.replaceAllMapped(
      RegExp(r'/[a-fA-F0-9\-]{8,}|/\d+'),
      (_) => '/{id}',
    );
  }

  /// Extracts the HTTP status code from a Dio log message or its metadata.
  ///
  /// Returns `'failed'` when the status code cannot be determined (e.g.
  /// connection timeout, cancelled).
  static String _extractDioStatus(
    String message,
    Map<String, String>? metadata,
  ) {
    // Check for explicit status code in metadata
    if (metadata != null && metadata.containsKey('status_code')) {
      return metadata['status_code']!;
    }

    // Parse from message format "· NNN ·"
    final match = RegExp(r'·\s*(\d{3})\s*·').firstMatch(message);
    if (match != null) return match.group(1)!;

    if (message.contains('cancelled')) return 'cancelled';
    if (message.contains('failed') || message.contains('error')) {
      return 'failed';
    }

    return 'unknown';
  }

  /// Extracts the error type prefix (the part before the first colon).
  ///
  /// Examples:
  /// - `'SocketException: Connection refused'` → `'SocketException'`
  /// - `'Exception: Auth failed'` → `'Exception'`
  /// - `'Auth failed'` → `'Auth failed'` (no colon — return whole string, normalized)
  static String _extractErrorTypePrefix(String message) {
    final colonIndex = message.indexOf(':');
    if (colonIndex > 0 && colonIndex < 60) {
      return message.substring(0, colonIndex).trim();
    }
    // No clear type prefix — normalize the whole message as a fallback
    return _normalizeMessage(message).substring(
      0,
      _normalizeMessage(message).length > 60
          ? 60
          : _normalizeMessage(message).length,
    );
  }

  /// Returns the first non-framework stack frame as `filename.dart:line`.
  ///
  /// Skips Flutter framework frames (`package:flutter/`, `dart:async`,
  /// `package:debug_kit/`) to surface the first app-level frame.
  static String? _extractFirstUsefulFrame(String? stackTrace) {
    if (stackTrace == null || stackTrace.isEmpty) return null;

    const skipPrefixes = [
      'package:flutter/',
      'package:debug_kit/',
      'dart:async',
      'dart:isolate',
      'dart:core',
      'package:stack_trace/',
    ];

    for (final line in stackTrace.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Skip framework frames
      final shouldSkip = skipPrefixes.any((prefix) => trimmed.contains(prefix));
      if (shouldSkip) continue;

      // Extract filename:line from "package:myapp/src/file.dart:42:10"
      final match =
          RegExp(r'([a-zA-Z_][a-zA-Z0-9_]*\.dart:\d+)').firstMatch(trimmed);
      if (match != null) return match.group(1)!;
    }

    return null;
  }

  /// Strips volatile values from a message to produce a stable grouping key.
  ///
  /// **What is removed / normalized:**
  /// - Standalone integers (durations like `5000ms`, IDs like `user_42`).
  /// - UUID-like hex sequences.
  /// - Memory address patterns (`#123 0x...`).
  /// - Leading/trailing whitespace.
  ///
  /// **What is preserved:**
  /// - Alphabetic keywords (e.g. `SocketException`, `timeout`, `failed`).
  /// - Path segments (grouped by [_extractDioPath] separately).
  /// - Error type prefixes.
  ///
  /// The result is lowercased and trimmed for stable comparison.
  static String _normalizeMessage(String message) {
    var normalized = message;

    // Remove memory addresses
    normalized = normalized.replaceAll(RegExp(r'#\d+\s+0x[0-9a-fA-F]+'), '');

    // Remove UUID-like patterns
    normalized = normalized.replaceAll(
      RegExp(
          r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b'),
      '',
    );

    // Remove standalone numbers (but keep exception type names like "HTTP 401")
    // Strategy: remove numbers that appear as standalone words or after
    // "after", "for", "timeout" keywords
    normalized = normalized.replaceAllMapped(
      RegExp(
          r'\b(after|timeout|for|in|took|within)\s+\d+(\s*(ms|s|ms|seconds?|milliseconds?))?\b',
          caseSensitive: false),
      (_) => '',
    );

    // Trim extra whitespace
    normalized =
        normalized.replaceAll(RegExp(r'\s{2,}'), ' ').trim().toLowerCase();

    return normalized;
  }
}
