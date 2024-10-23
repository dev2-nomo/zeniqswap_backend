import 'package:dart_frog/dart_frog.dart';

import '../main.dart';

Response onRequest(RequestContext context) {
  return Response(body: version);
}
