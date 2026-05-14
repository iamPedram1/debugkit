import '../controller/debug_kit_controller.dart';

abstract class DebugKitAdapter {
  void attach(DebugKitController controller);
  void dispose();
}
