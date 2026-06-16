import 'package:flutter/material.dart';
import '../../core/models/debug_trace_status.dart';

/// A small colored badge showing a [DebugTraceStatus].
class DebugTraceStatusBadge extends StatelessWidget {
  final DebugTraceStatus status;

  const DebugTraceStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _colorFor(DebugTraceStatus status) {
    return switch (status) {
      DebugTraceStatus.running => const Color(0xFF42A5F5),
      DebugTraceStatus.success => const Color(0xFF4CAF50),
      DebugTraceStatus.failed => const Color(0xFFF44336),
      DebugTraceStatus.cancelled => const Color(0xFFFF9800),
    };
  }
}
