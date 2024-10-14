import 'dart:async';
import 'dart:convert';
import 'package:walletkit_dart/walletkit_dart.dart';

import '../models/image_entity.dart';
import 'http_client.dart';
import 'logger.dart';
import 'price_repository.dart';

abstract class ImageRepository {
  static Future<ImageEntity?> getImage(CoinEntity token) async {
    final endpoint =
        '$PRICE_ENDPOINT/info/image/${token is ERC20Entity ? '${token.contractAddress}/${chaindIdMap[token.chainID]}' : token.name}';
    try {
      final result = await _getImage(endpoint).timeout(REQUEST_TIMEOUT_LIMIT);
      return result;
    } catch (e, s) {
      // Logger.logError(
      //   e,
      //   hint: 'Failed to fetch image from $endpoint',
      //   s: s,
      // );
      return null;
    }
  }

  static Future<ImageEntity> _getImage(String endpoint) async {
    Logger.logFetch(
      'Fetch Image from $endpoint',
      'PriceService Image',
    );

    final uri = Uri.parse(endpoint);

    final response = await HTTPService.client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(
      REQUEST_TIMEOUT_LIMIT,
      onTimeout: () => throw TimeoutException('Timeout', REQUEST_TIMEOUT_LIMIT),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'image_repository: Request returned status code ${response.statusCode}',
      );
    }
    final body = jsonDecode(response.body);

    if (body == null && body is! Json) {
      throw Exception(
        'image_repository: Request returned null: $endpoint',
      );
    }

    final image = ImageEntity.fromJson(body as Json);

    if (image.isPending) throw Exception('Image is pending');

    return image;
  }
}
