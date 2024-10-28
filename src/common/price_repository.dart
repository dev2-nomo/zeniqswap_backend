import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:walletkit_dart/walletkit_dart.dart';

import 'http_client.dart';
import 'logger.dart';
import '../models/pair_info.dart';

const REQUEST_TIMEOUT_LIMIT = Duration(seconds: 10);
const PRICE_ENDPOINT = 'https://price.zeniq.services/v2';

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

  @override
  String toString() {
    // TODO: implement toString
    return '{token: $token, price: $price, currency: $currency}';
  }

  PriceState get priceState => PriceState(
        price: price,
        currency: Currency.fromString(currency)!,
      );
}

abstract class PriceRepository {
  ///
  /// All Prices
  ///
  static Future<List<PriceEntity>> fetchAll({
    required Currency currency,
    required Iterable<CoinEntity> tokens,
  }) async {
    if (tokens.length <= 20) {
      return _fetchAllCatchEmpty(currency: currency, tokens: tokens);
    }

    final results = await Future.wait([
      for (var i = 0; i < tokens.length; i += 20)
        _fetchAllCatchEmpty(
          currency: currency,
          tokens: tokens.skip(i).take(20),
        ),
    ]);

    final result = results.reduce((value, element) => [...value, ...element]);

    return result;
  }

  static Future<List<PriceEntity>> _fetchAllCatchEmpty({
    required Currency currency,
    required Iterable<CoinEntity> tokens,
  }) async {
    final List<PriceEntity> prices = [];
    try {
      final priceEntities = await _fetchAll(
        currency: currency,
        tokens: tokens,
      );

      prices.addAll(priceEntities);
    } catch (e) {
      Logger.log("Price Fetch Error: $e", "PriceFetch");
      rethrow;
    }
    return prices;
  }

  static Future<List<PriceEntity>> _fetchAll({
    required Currency currency,
    required Iterable<CoinEntity> tokens,
  }) async {
    final uri = Uri.parse('$PRICE_ENDPOINT/currentpricelist');

    Logger.logFetch(
      "Fetch Price for [Assets=$tokens] in [Currency=$currency] from [Uri=$uri]",
      "PriceFetch",
    );

    final _tokens = tokens.map(
      (token) => switch (token) {
        zeniqTokenWrapper || wrappedZeniqSmart => zeniqSmart,
        _ => token,
      },
    );

    final _body = jsonEncode(
      [
        for (final token in _tokens)
          switch (token) {
            ERC20Entity token => [
                token.contractAddress,
                currency.name,
                'zeniq-smart-chain'
              ],
            _ => [
                token.name,
                currency.name,
              ],
          }
      ],
    );

    final response = await HTTPService.client
        .post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: _body,
        )
        .timeout(
          REQUEST_TIMEOUT_LIMIT,
          onTimeout: () =>
              throw TimeoutException("Timeout", REQUEST_TIMEOUT_LIMIT),
        );

    if (response.statusCode != 200) {
      throw Exception(
        "price_repository: $uri returned status code ${response.statusCode}",
      );
    }
    final body = jsonDecode(response.body);

    if (body == null || body is! List) {
      throw Exception(
        "price_repository: $uri returned null ($_tokens $currency)",
      );
    }

    return [
      for (int i = 0; i < body.length; i++)
        if (body[i] != null) PriceEntity.fromJson(body[i], _tokens[i]),
    ];
  }

  ///
  /// Single
  ///
  static Future<double> fetchSingle(
    CoinEntity token,
    Currency currency,
  ) async {
    final _token = switch (token) {
      zeniqTokenWrapper || wrappedZeniqSmart => zeniqSmart,
      _ => token,
    };

    final endpoint = _token is ERC20Entity
        ? '$PRICE_ENDPOINT/currentprice/${_token.contractAddress}/${currency.name}/zeniq-smart-chain'
        : '$PRICE_ENDPOINT/currentprice/${_token.name}/${currency.name}';
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
