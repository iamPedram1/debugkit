import 'package:debug_kit/debug_kit.dart';
import 'package:debug_kit_dio/debug_kit_dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

void main() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

  DebugKit.init(
    enabled: kDebugMode,
    adapters: [
      DebugKitDioAdapter(
        dio,
        config: const DebugKitDioConfig(
          // Body capture is disabled by default. Enable it only when the
          // sanitized preview is useful for local debugging.
          captureRequestBody: true,
          captureResponseBody: true,
          prettyPrintJson: true,
        ),
      ),
    ],
  );

  dio.get(
    '/users',
    queryParameters: {'page': 1, 'token': 'secret-token'},
  );
}
