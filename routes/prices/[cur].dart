import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../../src/common/price_repository.dart';
import '../../src/pool_provider.dart';

Future<Response> onRequest(
  RequestContext context,
  String cur,
) async {
  final currency = Currency.fromString(cur);

  if (currency == null) return Response(statusCode: HttpStatus.badRequest);

  final pairProvider = context.read<PairProvider>();
  await pairProvider.ready;

  final json = pairProvider.cache.read<String>('prices_$cur');

  return Response(
    body: json,
    headers: {'Content-Type': 'application/json'},
  );
}
