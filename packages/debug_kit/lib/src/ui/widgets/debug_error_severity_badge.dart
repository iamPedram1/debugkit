import 'package:flutter/material.dart';
import '../../core/models/debug_error_digest_severity.dart';

/// A small coloured pill badge showing the [DebugErrorDigestSeverity] label.
///
/// Used in the Errors tab list tiles and the error detail screen header.
/// Consistent style with [DebugTraceStatusBadge].
class DebugErrorSeverityBadge extends StatelessWidget {
  final DebugErrorDigestSeverity severity;

  const DebugErrorSeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        severity.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Color _colorFor(DebugErrorDigestSeverity severity) {
    return switch (severity) {
      DebugErrorDigestSeverity.fatal => const Color(0xFFFF1744),
      DebugErrorDigestSeverity.error => const Color(0xFFF44336),
      DebugErrorDigestSeverity.warning => const Color(0xFFFF9800),
    };
  }
}
