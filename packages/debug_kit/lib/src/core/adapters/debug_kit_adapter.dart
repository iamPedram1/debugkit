import '../controller/debug_kit_controller.dart';

/// Contract that all DebugKit integration adapters must implement.
///
/// An adapter bridges an external library (Dio, GoRouter, Riverpod, …) and
/// the DebugKit core. It receives a [DebugKitController] via [attach], uses it
/// to push sanitized log entries, and releases resources in [dispose].
///
/// **Rules for adapter implementors:**
/// - Sanitize all data before passing it to [DebugKitController.log].
/// - Always wrap logging calls in `try/catch` — adapters must fail silently.
/// - Never block the host application's execution path.
/// - Never log request/response bodies by default.
/// - Implement [dispose] to remove interceptors / observers cleanly.
///
/// ```dart
/// class MyAdapter extends DebugKitAdapter {
///   final MyLibrary _lib;
///   MyAdapter(this._lib);
///
///   @override
///   void attach(DebugKitController controller) {
///     _lib.addObserver(MyObserver(controller));
///   }
///
///   @override
///   void dispose() {
///     _lib.removeObserver();
///   }
/// }
/// ```
abstract class DebugKitAdapter {
  /// Creates an adapter instance.
  ///
  /// Implementations should attach external hooks in [attach], not in the
  /// constructor, so disabled DebugKit stays cheap.
  const DebugKitAdapter();

  /// Called by [DebugKitController.init] when DebugKit is enabled.
  ///
  /// The adapter should install its hooks (interceptors, observers, etc.) on
  /// the external library here. Implementations must guard against duplicate
  /// attachment if [attach] can be called multiple times.
  void attach(DebugKitController controller);

  /// Called when DebugKit is disposed or re-initialized.
  ///
  /// The adapter must remove all hooks installed in [attach] and release any
  /// held resources. After [dispose] the adapter should accept a subsequent
  /// [attach] call cleanly.
  void dispose();
}
