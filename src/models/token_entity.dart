import 'package:walletkit_dart/walletkit_dart.dart';

import 'pair_info.dart';

class TokenEntity extends ERC20Entity {
  final List<PairType> pairTypes;

  TokenEntity(
    ERC20Entity entity, {
    required this.pairTypes,
  }) : super(
          chainID: entity.chainID,
          contractAddress: entity.contractAddress,
          decimals: entity.decimals,
          name: entity.name,
          symbol: entity.symbol,
        );

  @override
  Json toJson() {
    return {
      "chainID": chainID,
      "contractAddress": contractAddress,
      "decimals": decimals,
      "name": name,
      "symbol": symbol,
      "pairTypes": pairTypes.map((e) => e.toString()).toList(),
    };
  }

  factory TokenEntity.fromJson(Map<String, dynamic> json) {
    return TokenEntity(
      ERC20Entity.fromJson(
        json,
        allowDeletion: false,
        chainID: json["chainID"] as int,
      ),
      pairTypes: (json["pairTypes"] as List<dynamic>)
          .map((e) =>
              PairType.values.firstWhere((element) => element.toString() == e))
          .toList(),
    );
  }
}
