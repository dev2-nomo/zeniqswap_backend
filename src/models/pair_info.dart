import 'package:walletkit_dart/walletkit_dart.dart';

import '../common/price_repository.dart';

enum PairType {
  legacy,
  v2;

  @override
  String toString() {
    return name;
  }

  static PairType fromString(String name) => PairType.values.singleWhere(
        (element) => element.name == name,
      );
}

const zeniqTokenWrapper = ERC20Entity(
  chainID: 383414847825,
  name: 'ZENIQ',
  symbol: 'ZENIQ Token',
  decimals: 18,
  contractAddress: '0x5b52bfB8062Ce664D74bbCd4Cd6DC7Df53Fd7233',
);

class PairInfo {
  PairInfo._({
    required this.pair,
    required this.token0,
    required this.token1,
    required this.reserve0,
    required this.reserve1,
    required this.type,
  });
  final UniswapV2Pair pair;
  final ERC20Entity token0;
  final ERC20Entity token1;
  final BigInt reserve0;
  final BigInt reserve1;

  final PairType type;

  ERC20Entity get token =>
      switch (token0) { zeniqTokenWrapper => token1, _ => token0 };

  int get decimalOffset0 => decimalDiff0 < 0 ? 0 : decimalDiff0;
  int get decimalOffset1 => decimalDiff1 < 0 ? 0 : decimalDiff1;

  int get decimalDiff0 => token1.decimals - token0.decimals;
  int get decimalDiff1 => token0.decimals - token1.decimals;

  BigInt get reserve0Adjusted => reserve0 * BigInt.from(10).pow(decimalOffset0);
  BigInt get reserve1Adjusted => reserve1 * BigInt.from(10).pow(decimalOffset1);

  double get ratio0 => reserve0Adjusted / reserve1Adjusted;
  double get ratio1 => reserve1Adjusted / reserve0Adjusted;

  PriceState calculateTokenPrice(PriceState zeniqPrice) {
    return PriceState(
      price: zeniqPrice.price * zeniqRatio,
      currency: zeniqPrice.currency,
    );
  }

  double get zeniqRatio => switch (token0) {
        zeniqTokenWrapper => ratio0,
        _ => ratio1,
      };

  Amount get zeniqAmount => switch (token0) {
        zeniqTokenWrapper => amount0,
        _ => amount1,
      };

  Amount get tokenAmount => switch (token0) {
        zeniqTokenWrapper => amount1,
        _ => amount0,
      };

  Amount get amount0 => Amount(
        value: reserve0,
        decimals: token0.decimals,
      );

  Amount get amount1 => Amount(
        value: reserve1,
        decimals: token1.decimals,
      );

  Amount calculateAmount0FromAmount1(Amount amount1) {
    final amount1Adjusted = amount1.value * BigInt.from(10).pow(decimalOffset1);
    final amount0BI = amount1Adjusted.multiply(ratio0);
    return Amount(
      value: amount0BI,
      decimals: token0.decimals,
    );
  }

  Amount calculateAmount1FromAmount0(Amount amount0) {
    final amount0Adjusted = amount0.value * BigInt.from(10).pow(decimalOffset0);
    final amount1BI = amount0Adjusted.multiply(ratio1);
    return Amount(
      value: amount1BI,
      decimals: token1.decimals,
    );
  }

  double calculatePoolShare(Amount amount0, Amount amount1) {
    final amount0Adj = amount0.value * BigInt.from(10).pow(decimalOffset0);
    final amount1Adj = amount1.value * BigInt.from(10).pow(decimalOffset1);

    final totalValue = amount0Adj + amount1Adj;

    return (totalValue / (reserve0Adjusted + reserve1Adjusted + totalValue)) *
        100;
  }

  double totalValueLocked(double price0, double price1) {
    return amount0.displayDouble * price0 + amount1.displayDouble * price1;
  }

  double percentageOfTvl0(double price0, double price1) {
    final tvl = totalValueLocked(price0, price1);
    return (amount0.displayDouble * price0 / tvl) * 100;
  }

  double percentageOfTvl1(double price0, double price1) {
    final tvl = totalValueLocked(price0, price1);
    return (amount1.displayDouble * price1 / tvl) * 100;
  }

  static Future<PairInfo?> fromPair(
    UniswapV2Pair pair, {
    required PairType type,
  }) async {
    final results = await Future.wait([
      pair.token0().then(
            (contractAddress) => getTokenInfo(
              contractAddress: contractAddress,
              rpc: pair.rpc,
            ).then(
              (info) => info?.toEntity(
                pair.rpc.type.chainId,
              ),
            ),
          ),
      pair.token1().then(
            (contractAddress) => getTokenInfo(
              contractAddress: contractAddress,
              rpc: pair.rpc,
            ).then(
              (info) => info?.toEntity(
                pair.rpc.type.chainId,
              ),
            ),
          ),
      pair.getReserves(),
    ]);

    final token0 = results[0] as ERC20Entity?;
    final token1 = results[1] as ERC20Entity?;

    if (token1 == null || token0 == null) return null;

    final (reserves0, reserves1) = results[2] as (BigInt, BigInt);

    return PairInfo._(
      pair: pair,
      token0: token0,
      token1: token1,
      reserve0: reserves0,
      reserve1: reserves1,
      type: type,
    );
  }

  Future<PairInfo> update() async {
    final (reserve0, reserve1) = await pair.getReserves();

    return copyWith(
      reserve0: reserve0,
      reserve1: reserve1,
    );
  }

  PairInfo copyWith({
    BigInt? reserve0,
    BigInt? reserve1,
  }) =>
      PairInfo._(
        pair: pair,
        token0: token0,
        token1: token1,
        type: type,
        reserve0: reserve0 ?? this.reserve0,
        reserve1: reserve1 ?? this.reserve1,
      );

  @override
  String toString() {
    return '(token0: $token0, token1: $token1, reserve0: $reserve0, reserve1: $reserve1)';
  }

  Map<String, dynamic> toJson() => {
        'token0': token0.toJson(),
        'token1': token1.toJson(),
        'pair': pair.contractAddress,
        'type': type.index,
        'reserve0': reserve0.toString(),
        'reserve1': reserve1.toString(),
      };
}

extension on TokenInfo {
  ERC20Entity toEntity(int chainID) => ERC20Entity(
        name: name,
        symbol: symbol,
        decimals: decimals,
        chainID: chainID,
        contractAddress: contractAddress,
      );
}
