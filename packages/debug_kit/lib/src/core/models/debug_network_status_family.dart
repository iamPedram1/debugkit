/// Response status family for a network transaction.
enum DebugNetworkStatusFamily {
  twoXX,
  threeXX,
  fourXX,
  fiveXX,
  unknown;

  /// Human-readable label used in chips and export sections.
  String get label {
    return switch (this) {
      DebugNetworkStatusFamily.twoXX => '2xx',
      DebugNetworkStatusFamily.threeXX => '3xx',
      DebugNetworkStatusFamily.fourXX => '4xx',
      DebugNetworkStatusFamily.fiveXX => '5xx',
      DebugNetworkStatusFamily.unknown => 'Unknown',
    };
  }
}
