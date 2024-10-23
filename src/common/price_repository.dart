import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:walletkit_dart/walletkit_dart.dart';

import 'http_client.dart';
import 'logger.dart';
import '../models/pair_info.dart';

const REQUEST_TIMEOUT_LIMIT = Duration(seconds: 10);
const PRICE_ENDPOINT = 'https://price.zeniq.services/v2';

const chaindIdMap = {
  383414847825: 'zeniq-smart-chain',
};

enum Currency {
  usd('US Dollar', '\$'),
  eur('Euro', '€');
  // gbp,
  // chf;

  final String displayName;
  final String symbol;

  const Currency(this.displayName, this.symbol);

  @override
  String toString() => name;

  static Currency? fromString(String cur) =>
      Currency.values.singleWhereOrNull((element) => element.name == cur);
}

class PriceState {
  final double price;
  final Currency currency;

  const PriceState({
    required this.price,
    required this.currency,
  });
}

class PriceEntity {
  const PriceEntity({
    required this.token,
    required this.symbol,
    required this.price,
    required this.isPending,
    required this.currency,
  });
  factory PriceEntity.fromJson(Map<String, dynamic> json, CoinEntity token) =>
      PriceEntity(
        symbol: json['symbol'] as String,
        price: (json['price'] as num).toDouble(),
        currency: json['fiat'] as String,
        isPending: json['isPending'] as bool,
        token: token,
      );
  final String symbol;
  final CoinEntity token;
  final double price;
  final bool isPending;
  final String currency;
}

abstract class PriceRepository {
  ///
  /// Single
  ///
  static Future<double> fetchSingle(
    CoinEntity token,
    Currency currency,
  ) async {
    final endpoint = token is ERC20Entity
        ? '$PRICE_ENDPOINT/currentprice/${token.contractAddress}/${currency.name}/${chaindIdMap[token.chainID]!}'
        : '$PRICE_ENDPOINT/currentprice/${token.name}/${currency.name}';
    try {
      final price = await _fetchSingle(
        endpoint: endpoint,
        currency: currency.name,
        token: token,
      ).timeout(REQUEST_TIMEOUT_LIMIT);

      return price;
    } catch (e) {
      rethrow;
    }
  }

  static Future<double> _fetchSingle({
    required String endpoint,
    required String currency,
    required CoinEntity token,
  }) async {
    final uri = Uri.parse(endpoint);

    Logger.logFetch(
      'Fetch Price from $endpoint',
      'PriceFetch',
    );

    final response = await HTTPService.client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(
      REQUEST_TIMEOUT_LIMIT,
      onTimeout: () => throw TimeoutException('Timeout', REQUEST_TIMEOUT_LIMIT),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'price_repository: $endpoint returned status code ${response.statusCode}',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>?;

    if (body == null) {
      throw Exception(
        'price_repository: $endpoint returned null',
      );
    }

    final priceEntity = PriceEntity.fromJson(body, token);
    Logger.log('Price Entity pending: ${priceEntity.isPending}', 'PriceFetch');
    if (priceEntity.isPending) {
      throw Exception(
        'price_repository: $endpoint returned pending',
      );
    }

    return priceEntity.price;
  }
}

extension TokenName on CoinEntity {
  String get name {
    if (this == zeniqCoin || this == zeniqSmart || this == zeniqTokenWrapper) {
      return zeniqCoin.name.toLowerCase();
    } else {
      return symbol.toLowerCase();
    }
  }
}
