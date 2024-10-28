import 'dart:async';
import 'dart:convert';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'common/image_repository.dart';
import 'common/logger.dart';
import 'common/price_repository.dart';
import 'common/token_repository.dart';
import 'models/image_entity.dart';
import 'models/pair_info.dart';
import 'models/token_entity.dart';
import 'package:collection/collection.dart';

final rpc = EvmRpcInterface(
  type: ZeniqSmartNetwork,
  useQueuedManager: false,
  clients: [
    EvmRpcClient(zeniqSmartRPCEndpoint),
  ],
);

final factoryNew = UniswapV2Factory(
  rpc: rpc,
  contractAddress: '0x40a4E23Cc9E57161699Fd37c0A4d8bca383325f3',
);

final factoryOld = UniswapV2Factory(
  rpc: rpc,
  contractAddress: '0x7D0cbcE25EaaB8D5434a53fB3B42077034a9bB99',
);

class PairProvider {
  final List<Currency> currencies = [Currency.eur, Currency.usd];

  PairProvider._();
  final Map<String, dynamic> cache = {};

  static final PairProvider _instance = PairProvider._();

  static PairProvider get instance => _instance;

  final Completer<void> _completer = Completer<void>();

  Future<void> get ready => _completer.future;

  List<PairInfo> pairs = [];

  Map<Currency, Map<ERC20Entity, Map<PairType, double>>> pairTokenPrices = {};

  Set<TokenEntity> tokens = {};

  Set<ERC20Entity> fixedTokens = {};

  Map<Currency, List<PriceEntity>> priceServicePrices = {};

  Map<ERC20Entity, ImageEntity?> tokenImages = {};

  Future<void> init() async {
    await update();
    await updateNoPriority();

    if (!_completer.isCompleted) {
      _completer.complete();
    }

    Timer.periodic(const Duration(minutes: 1), (timer) {
      update();
    });

    Timer.periodic(const Duration(hours: 1), (timer) {
      updateNoPriority();
    });
  }

  Future<void> updateNoPriority() async {
    await fetchFixedTokens();
    await fetchTokenImages();
  }

  Future<void> update() async {
    await fetchPairs();
    await fetchPrices();
  }

  Future<void> fetchPrices() async {
    final newPairTokenPrices =
        <Currency, Map<ERC20Entity, Map<PairType, double>>>{};

    try {
      var newPriceServicePrices = {
        for (final cur in currencies)
          cur: await PriceRepository.fetchAll(
            tokens: tokens,
            currency: cur,
          ),
      };
      priceServicePrices = newPriceServicePrices;
    } catch (e, s) {
      Logger.logError(e, s: s);
    }

    final zeniqPrices = {
      for (final cur in currencies)
        cur: priceServicePrices[cur]?.firstWhereOrNull(
          (element) => element.token == zeniqSmart,
        ),
    };

    if (zeniqPrices.isEmpty || zeniqPrices.values.contains(null)) {
      return;
    }

    for (var i = 0; i < currencies.length; i++) {
      final cur = currencies[i];
      final zeniqPrice = zeniqPrices[cur]!;

      final priceServicePrices = this.priceServicePrices[cur]!;

      newPairTokenPrices[cur] = {};

      for (final pair in pairs) {
        final token = pair.token;

        // Skip if the token is in PriceService
        final existingPriceState = priceServicePrices.singleWhereOrNull(
          (element) => element.token == token,
        );
        if (existingPriceState != null) {
          newPairTokenPrices[cur]!.update(
            pair.token,
            (value) {
              return {
                ...value,
                pair.type: existingPriceState.price,
              };
            },
            ifAbsent: () => {
              pair.type: existingPriceState.price,
            },
          );

          continue;
        }

        final priceState = pair.calculateTokenPrice(zeniqPrice.priceState);
        newPairTokenPrices[cur]!.update(
          pair.token,
          (value) {
            return {
              ...value,
              pair.type: priceState.price,
            };
          },
          ifAbsent: () => {
            pair.type: priceState.price,
          },
        );
      }

      final json = {
        'zeniqPrice': zeniqPrice.price,
        'tokenPrices': [
          for (final entry in newPairTokenPrices[cur]!.entries)
            {
              'token': entry.key.contractAddress,
              'prices': entry.value.map(
                (key, value) {
                  return MapEntry(key.name, value);
                },
              )
            },
        ],
      };

      final jsonString = jsonEncode(json);
      cache.put('prices_$cur', jsonString);
    }

    pairTokenPrices = newPairTokenPrices;
  }

  Future<void> fetchFixedTokens() async {
    try {
      final fixedTokens = await TokenRepository.fetchFixedTokens();

      this.fixedTokens = {
        ...fixedTokens,
        zeniqTokenWrapper,
        wrappedZeniqSmart,
      };
    } catch (e) {
      Logger.logError(e);
    }
  }

  Future<void> fetchTokenImages() async {
    final results = await Future.wait(
      [
        for (final token in tokens)
          ImageRepository.getImage(
            switch (token) {
              zeniqTokenWrapper || wrappedZeniqSmart => zeniqSmart,
              _ => token,
            },
          ),
      ],
    );

    tokenImages = {
      for (var i = 0; i < tokens.length; i++) tokens.elementAt(i): results[i],
    };
  }

  Future<void> fetchPairs() async {
    try {
      final pairsNew = await fetchAllPairs(factoryNew, type: PairType.v2);
      final pairsOld = await fetchAllPairs(factoryOld, type: PairType.legacy);
      pairs = [...pairsNew, ...pairsOld];

      final json = {
        'pairs': pairs,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };

      cache.put('pairsJson', jsonEncode(json));

      final newTokens = <TokenEntity>[];

      for (final pair in pairs) {
        final token = TokenEntity(
          pair.token,
          pairTypes: [pair.type],
        );
        if (newTokens.contains(token) == false) {
          newTokens.add(
            TokenEntity(
              pair.token,
              pairTypes: [pair.type],
            ),
          );
        } else {
          final index = newTokens.indexOf(token);
          newTokens[index].pairTypes.add(pair.type);
        }
      }

      tokens = {
        TokenEntity(zeniqTokenWrapper, pairTypes: [PairType.v2]),
        TokenEntity(wrappedZeniqSmart, pairTypes: [PairType.legacy]),
        ...newTokens.toSet(),
      };
    } catch (e, s) {
      Logger.logError(e, s: s);
    }
  }
}

extension CacheUtils on Map<String, dynamic> {
  void put(String key, dynamic value) {
    this[key] = value;
  }

  T read<T>(String key) {
    return this[key] as T;
  }
}

Future<List<PairInfo>> fetchAllPairs(
  UniswapV2Factory factory, {
  required PairType type,
}) async {
  final length = await factory.allPairsLength().then((value) => value.toInt());

  final pairs = await Future.wait([
    for (int i = 0; i < length; i++)
      factory
          .allPairs(i.toBigInt)
          .then(
            (contractAddress) => UniswapV2Pair(
              rpc: rpc,
              contractAddress: contractAddress,
            ),
          )
          .then(
            (pair) => PairInfo.fromPair(pair, type: type),
          ),
  ]).then((pairsNullable) => pairsNullable.whereType<PairInfo>().toList());

  return pairs;
}
