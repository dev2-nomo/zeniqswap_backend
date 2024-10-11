import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as shelf;
import '../src/pool_provider.dart';

const frontendUrl = 'https://dex.zeniqswap.com';

Handler middleware(Handler handler) {
  return handler
      .use(requestLogger())
      .use(provider<PairProvider>((c) => PairProvider.instance))
      .use(
        fromShelfMiddleware(
          shelf.corsHeaders(
            headers: {
              shelf.ACCESS_CONTROL_ALLOW_ORIGIN:
                  Platform.environment['FRONTEND_URL'] ?? frontendUrl,
            },
          ),
        ),
      );
}
