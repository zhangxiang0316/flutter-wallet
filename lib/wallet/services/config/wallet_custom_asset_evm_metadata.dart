part of 'wallet_custom_asset_service.dart';

Future<WalletAsset> _fetchEvmTokenMetadata({
  required Dio dio,
  required WalletChainConfig chain,
  required String contractAddress,
}) async {
  if (!chain.isEvm) {
    throw const CustomAssetUnsupportedChainException();
  }
  final address = WalletTransferService.normalizeEvmAddress(contractAddress);
  final results = await Future.wait([
    _evmCall(dio: dio, chain: chain, to: address, data: '0x95d89b41'),
    _evmCall(dio: dio, chain: chain, to: address, data: '0x06fdde03'),
    _evmCall(dio: dio, chain: chain, to: address, data: '0x313ce567'),
  ]);
  final symbol = _decodeAbiString(results[0]).trim();
  final name = _decodeAbiString(results[1]).trim();
  final decimals = _decodeAbiUint(results[2]).toInt();
  if (symbol.isEmpty || decimals < 0 || decimals > 30) {
    throw const CustomAssetInvalidMetadataException();
  }
  return WalletAsset.config(
    chainConfig: chain,
    symbol: symbol.toUpperCase(),
    name: name.isEmpty ? symbol.toUpperCase() : name,
    decimals: decimals,
    contractAddress: address,
    logoUrl: _defaultLogoUrl(chain, address),
    isCustom: true,
  );
}

/// 执行一次 EVM `eth_call`。
///
/// 添加代币时所有元数据读取都走该方法。它会遍历当前链的 RPC fallback 列表，
/// 直到拿到字符串类型的 result。
Future<String> _evmCall({
  required Dio dio,
  required WalletChainRef chain,
  required String to,
  required String data,
}) async {
  final responseData = await RpcRetryHelper.executeJsonRpc(
    dio: dio,
    rpcUrls: _evmRpcUrls(chain),
    method: 'eth_call',
    params: [
      {'to': to, 'data': data},
      'latest',
    ],
    chainName: chain.name,
    logName: 'WalletCustomAssetService',
  );
  final result = responseData['result'];
  if (result is String) {
    return result;
  }
  throw StateError(responseData.toString());
}

/// 解析 ABI string 返回值。
///
/// 大多数 ERC20 合约返回动态 string，少数老合约返回 bytes32。这里兼容两种：
/// - 动态 string：offset + length + utf8 bytes；
/// - bytes32：固定 32 字节，去掉尾部 0 后按 UTF-8 解码。
String _decodeAbiString(String value) {
  final clean = value.replaceFirst('0x', '');
  if (clean.isEmpty || clean == '0' || clean.length.isOdd) {
    return '';
  }
  if (clean.length >= 128) {
    final offset = BigInt.tryParse(clean.substring(0, 64), radix: 16)?.toInt();
    final lengthWordStart = (offset ?? -1) * 2;
    if (offset != null && offset >= 0 && clean.length >= lengthWordStart + 64) {
      final length = BigInt.tryParse(
        clean.substring(lengthWordStart, lengthWordStart + 64),
        radix: 16,
      )?.toInt();
      if (length != null && length > 0) {
        final dataStart = lengthWordStart + 64;
        final dataEnd = dataStart + (length * 2);
        if (clean.length >= dataEnd) {
          return utf8.decode(
            hex.decode(clean.substring(dataStart, dataEnd)),
            allowMalformed: true,
          );
        }
      }
    }
  }

  if (clean.length == 64) {
    final bytes = hex.decode(clean);
    var end = bytes.length;
    while (end > 0 && bytes[end - 1] == 0) {
      end--;
    }
    final text = utf8.decode(bytes.sublist(0, end), allowMalformed: true);
    if (text.trim().isNotEmpty) {
      return text;
    }
  }
  return '';
}

/// 解析 ABI uint 返回值。
///
/// decimals() 返回 uint8/uint256 时都可以按十六进制整数解析。
BigInt _decodeAbiUint(String value) {
  final clean = value.replaceFirst('0x', '');
  if (clean.isEmpty) {
    return BigInt.zero;
  }
  return BigInt.parse(clean, radix: 16);
}
