import 'dart:async';
import 'dart:convert';

import 'package:walletkit_dart/walletkit_dart.dart';

import 'http_client.dart';

abstract class TokenRepository {
  static const String endpoint = "https://webon.info/api/tokens";

  static Future<List<ERC20Entity>> fetchFixedTokens() async {
    final response = await HTTPService.client.get(
      Uri.parse(endpoint),
      headers: {"Content-Type": "application/json"},
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException("Timeout", Duration(seconds: 15)),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "token_repository: Request returned status code ${response.statusCode}",
      );
    }
    final body = jsonDecode(response.body);

    if (body == null && body is! List<dynamic>) {
      throw Exception(
        "token_repository: Request returned null: $endpoint",
      );
    }

    return [
      for (Map<String, dynamic> jsonMap in body)
        () {
          if (jsonMap
              case {
                "name": String _,
                "symbol": String _,
                "decimals": int _,
                "contractAddress": String _,
                "chainId": String chainId,
                "is_nft": false,
                "type": "ZEN-20",
              }) {
            final chainId_i = int.tryParse(chainId);
            if (chainId_i == null) {
              return null;
            }
            return ERC20Entity.fromJson(
              jsonMap,
              allowDeletion: true,
              chainID: chainId_i,
            );
          }
          return null;
        }.call()
    ].whereType<ERC20Entity>().toList();
  }
}
