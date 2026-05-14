enum DebugLogSource {
  app,
  dio,
  riverpod,
  router,
  userAction;

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
