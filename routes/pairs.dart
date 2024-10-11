import 'package:dart_frog/dart_frog.dart';
import '../src/pool_provider.dart';

const cacheDuration = Duration(minutes: 1);

Future<Response> onRequest(RequestContext context) async {
  final pairProvider = context.read<PairProvider>();
  await pairProvider.ready;

  final cachedPairsJson = pairProvider.cache.read<String>('pairsJson');

  return Response(
    body: cachedPairsJson,
    headers: {'Content-Type': 'application/json'},
  );
}
