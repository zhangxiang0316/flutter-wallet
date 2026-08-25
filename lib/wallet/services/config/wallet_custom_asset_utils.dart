part of 'wallet_custom_asset_service.dart';

/// EVM 链元数据查询备用 RPC 节点。
///
/// 添加自定义 EVM 资产时需要调用合约的 symbol/name/decimals。公共节点不稳定时，
/// 按顺序切换到备用节点，提高添加成功率。
const Map<WalletChain, List<String>> _evmRpcFallbacks = {
  WalletChain.bsc: [
    'https://bsc-dataseed.bnbchain.org',
    'https://bsc-rpc.publicnode.com',
  ],
  WalletChain.ethereum: [
    'https://ethereum-rpc.publicnode.com',
    'https://eth.llamarpc.com',
  ],
  WalletChain.xLayer: ['https://rpc.xlayer.tech', 'https://xlayerrpc.okx.com'],
  WalletChain.arbitrum: [
    'https://arb1.arbitrum.io/rpc',
    'https://arbitrum-one-rpc.publicnode.com',
  ],
  WalletChain.base: [
    'https://mainnet.base.org',
    'https://base-rpc.publicnode.com',
  ],
  WalletChain.polygon: [
    'https://polygon.drpc.org',
    'https://polygon.publicnode.com',
  ],
  WalletChain.avalanche: [
    'https://api.avax.network/ext/bc/C/rpc',
    'https://avalanche-c-chain-rpc.publicnode.com',
  ],
};

String? _normalizeLogoUrl(String? value) {
  final logoUrl = value?.trim() ?? '';
  if (logoUrl.isEmpty) return null;
  final uri = Uri.tryParse(logoUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw const CustomAssetInvalidInputException();
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    throw const CustomAssetInvalidInputException();
  }
  return uri.toString();
}

String? _defaultLogoUrl(WalletChainRef chain, String contractAddress) {
  if (!chain.isEvm) return null;
  final folder = _trustWalletFolders[chain.id];
  if (folder == null) return null;
  return _trustWalletLogo(folder, contractAddress);
}

const Map<String, String> _trustWalletFolders = {
  'ethereum': 'ethereum',
  'bsc': 'smartchain',
  'arbitrum': 'arbitrum',
  'base': 'base',
  'polygon': 'polygon',
  'avalanche': 'avalanchec',
};

String _trustWalletLogo(String folder, String contractAddress) {
  final address = contractAddress.startsWith('0x')
      ? _checksumEvmAddress(contractAddress)
      : contractAddress;
  return 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/$folder/assets/$address/logo.png';
}

String _checksumEvmAddress(String address) {
  final clean = address.replaceFirst('0x', '').toLowerCase();
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(clean)) {
    return address;
  }
  final digest = KeccakDigest(256);
  final hash = hex.encode(digest.process(Uint8List.fromList(clean.codeUnits)));
  final buffer = StringBuffer('0x');
  for (var index = 0; index < clean.length; index++) {
    final hashValue = int.parse(hash[index], radix: 16);
    buffer.write(hashValue >= 8 ? clean[index].toUpperCase() : clean[index]);
  }
  return buffer.toString();
}

/// 按链类型校验和标准化合约地址。
///
/// EVM 地址会被标准化为 checksum 地址；TRON/Solana 地址只做合法性校验并保留用户输入。
String _normalizeAddress(
  WalletChainRef chain,
  String? address,
  ChainAdapterRegistry adapterRegistry,
) {
  final value = address?.trim() ?? '';
  if (value.isEmpty) {
    throw const CustomAssetInvalidInputException();
  }
  final adapter = adapterRegistry.require(
    chain,
    capability: ChainCapability.customAssets,
  );
  return adapter.normalizeAddress(value);
}

/// 判断资产列表中是否已存在目标资产。
bool _containsAsset(List<WalletAsset> assets, WalletAsset target) {
  return assets.any((asset) => _sameContractAsset(asset, target));
}

/// 判断两个资产是否代表同一链上的同一合约。
bool _sameContractAsset(WalletAsset asset, WalletAsset target) {
  return asset.chainId == target.chainId &&
      _contractKey(asset.chainRef, asset.contractAddress) ==
          _contractKey(target.chainRef, target.contractAddress);
}

/// 生成合约比较 key。
///
/// EVM 合约地址大小写不敏感，比较时统一转小写；非 EVM 地址按原值比较。
String _contractKey(WalletChainRef chain, String? contractAddress) {
  final value = contractAddress?.trim() ?? '';
  if (value.isEmpty) {
    return 'native';
  }
  return chain.isEvm ? value.toLowerCase() : value;
}

List<String> _evmRpcUrls(WalletChainRef chain) {
  if (chain is WalletChainConfig && !chain.isBuiltin) {
    return chain.rpcUrls;
  }
  if (chain is WalletChain && _evmRpcFallbacks.containsKey(chain)) {
    return _evmRpcFallbacks[chain]!;
  }
  if (chain is WalletChainConfig && chain.builtinChain != null) {
    return RpcRetryHelper.mergeRpcUrls(
      chain.rpcUrls,
      _evmRpcFallbacks[chain.builtinChain] ?? const [],
    );
  }
  return [chain.rpcUrl];
}
