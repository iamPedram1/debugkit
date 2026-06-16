/// The origin of a [DebugLogEntry] — which subsystem produced the log.
///
/// Each adapter package uses a dedicated source value so logs can be filtered
/// by origin in the console UI.
enum DebugLogSource {
  /// A log emitted directly by the application via [DebugKit.log].
  app,

  /// A log produced by the Dio network adapter (`debug_kit_dio`).
  dio,

  /// A log produced by the Riverpod state observer (`debug_kit_riverpod`).
  riverpod,

  /// A log produced by the GoRouter navigation observer (`debug_kit_go_router`).
  router,

  /// A log representing a deliberate user interaction (e.g. button taps).
  ///
  /// Emitted via [DebugKit.log.userAction].
  userAction;

  /// Short uppercase label shown in the console UI and export files.
  ///
  /// - [app]        → `'APP'`
  /// - [dio]        → `'DIO'`
  /// - [riverpod]   → `'RVP'`
  /// - [router]     → `'NAV'`
  /// - [userAction] → `'USER'`
  String get label {
    return switch (this) {
      DebugLogSource.app => 'APP',
      DebugLogSource.dio => 'DIO',
      DebugLogSource.riverpod => 'RVP',
      DebugLogSource.router => 'NAV',
      DebugLogSource.userAction => 'USER',
    };
  }
}
