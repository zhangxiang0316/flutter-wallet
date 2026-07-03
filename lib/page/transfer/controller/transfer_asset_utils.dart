import '../../../wallet/models/chain_balance.dart';

class TransferAssetUtils {
  const TransferAssetUtils._();

  /// 构建资产唯一 key。
  static String assetKey(ChainBalance asset) {
    final contract = asset.contractAddress?.trim() ?? '';
    final normalizedContract = asset.chainRef.isEvm
        ? contract.toLowerCase()
        : contract;
    return [
      asset.chainId,
      normalizedContract.isEmpty ? 'native' : normalizedContract,
      asset.symbol.toUpperCase(),
    ].join(':');
  }

  /// 去重资产列表。
  ///
  /// 同一条链上的同一合约只保留一条，避免下拉框出现重复币种。
  static List<ChainBalance> deduplicateAssets(List<ChainBalance> assets) {
    final keys = <String>{};
    final result = <ChainBalance>[];
    for (final asset in assets) {
      if (keys.add(assetKey(asset))) {
        result.add(asset);
      }
    }
    return result;
  }
}
