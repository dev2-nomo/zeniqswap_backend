import 'package:test/test.dart';

import '../src/models/pair_info.dart';
import '../src/pool_provider.dart';

void main() {
  test("Fetch Pairs", () async {
    final pairsNew = await fetchAllPairs(factoryNew, type: PairType.v2);

    print(pairsNew.length);
  });
}
