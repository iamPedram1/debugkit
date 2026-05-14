import 'package:dio/dio.dart';
import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit/src/core/controller/debug_kit_controller.dart';
import 'debug_kit_dio_interceptor.dart';

/// A DebugKit adapter that integrates Dio network logging.
class DebugKitDioAdapter extends DebugKitAdapter {
  /// The Dio instance to intercept.
  final Dio dio;

  DebugKitDioInterceptor? _interceptor;

  DebugKitDioAdapter(this.dio);

  @override
  void attach(DebugKitController controller) {
    _interceptor = DebugKitDioInterceptor(controller);
    dio.interceptors.add(_interceptor!);
  }

  @override
  void dispose() {
    if (_interceptor != null) {
      dio.interceptors.remove(_interceptor);
      _interceptor = null;
    }
  }
}
