import 'package:test/test.dart';
import 'package:walletkit_dart/walletkit_dart.dart';

import '../src/common/price_repository.dart';
import '../src/models/pair_info.dart';

void main() {
  test(
    "Fetch Single Zeniq Price",
    () async {
      final price = await PriceRepository.fetchSingle(
        zeniqSmart,
        Currency.usd,
      );

      final price2 = await PriceRepository.fetchSingle(
        zeniqTokenWrapper,
        Currency.usd,
      );

      final price3 = await PriceRepository.fetchSingle(
        wrappedZeniqSmart,
        Currency.usd,
      );

      expect(price, price3);
      expect(price, price2);
    },
  );

  test(
    "Test Fetch Multiple Prices",
    () async {
      final prices = await PriceRepository.fetchAll(
        tokens: [
          zeniqSmart,
        ],
        currency: Currency.usd,
      );

      print(prices);
    },
  );
}
