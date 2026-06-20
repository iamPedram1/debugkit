/// Aggregate breakdown of network response status families.
///
/// Counts are derived from sanitized log entries when building a
/// [DebugNetworkSummary].
class DebugNetworkStatusBreakdown {
  final int status2xx;
  final int status3xx;
  final int status4xx;
  final int status5xx;
  final int statusUnknown;

  const DebugNetworkStatusBreakdown({
    required this.status2xx,
    required this.status3xx,
    required this.status4xx,
    required this.status5xx,
    required this.statusUnknown,
  });

  const DebugNetworkStatusBreakdown.empty()
      : status2xx = 0,
        status3xx = 0,
        status4xx = 0,
        status5xx = 0,
        statusUnknown = 0;
}
