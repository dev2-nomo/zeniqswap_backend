import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../src/pool_provider.dart';

Future<Response> onRequest(RequestContext context) async {
  final pairProvider = context.read<PairProvider>();
  await pairProvider.ready;

  final json = [
    for (final token in pairProvider.tokens)
      {
        ...token.toJson(),
        'pairTypes': token.pairTypes.map((e) => e.toString()).toList(),
        'image': pairProvider.tokenImages[token]?.large,
        'fixed': pairProvider.fixedTokens.contains(token),
      }
  ];

  final jsonString = jsonEncode(json);

  return Response(
    body: jsonString,
    headers: {'Content-Type': 'application/json'},
  );
}
