import 'dart:async';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'src/pool_provider.dart';

const version = "1.0.8";

Future<void> init(InternetAddress ip, int port) async {
  unawaited(PairProvider.instance.init());
}

Future<HttpServer> run(Handler handler, InternetAddress ip, int port) {
  // 1. Execute any custom code prior to starting the server...

  // 2. Use the provided `handler`, `ip`, and `port` to create a custom `HttpServer`.
  // Or use the Dart Frog serve method to do that for you.
  return serve(handler, ip, port);
}
