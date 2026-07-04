/// Dio adapter for DebugKit network logging.
///
/// Adds a Dio interceptor that records sanitized request lifecycle metadata
/// into DebugKit without capturing bodies unless explicitly configured.
library debug_kit_dio;

export 'src/debug_kit_dio_adapter.dart';
export 'src/debug_kit_dio_config.dart';
export 'src/debug_kit_dio_interceptor.dart';
