import '../../models/chain_balance.dart';
import '../../models/wallet_chain.dart';

/// 区块浏览器地址构造服务。
///
/// 交易历史接口不稳定或未配置 API Key 时，页面可以退回到浏览器查看地址维度的
/// 链上记录。这里集中维护各条链的默认地址页，避免 UI 里散落 explorer URL。
class WalletBlockExplorerService {
  const WalletBlockExplorerService();

  /// 返回当前资产所在链的钱包地址浏览器 URL。
  ///
  /// 当前点击的是某个币种，但大多数浏览器都以地址页为入口，再在页面内筛选
  /// token transfers，因此这里统一打开钱包地址页。
  Uri? addressUri(ChainBalance asset) {
    final template = _addressTemplate(asset.chainRef);
    if (template == null) return null;
    return Uri.parse(template.replaceAll('{address}', asset.address.trim()));
  }

  /// 返回当前资产所在链的交易详情浏览器 URL。
  Uri? transactionUri(ChainBalance asset, String txHash) {
    final hash = txHash.trim();
    if (hash.isEmpty) return null;
    final template = _transactionTemplate(asset.chainRef);
    if (template == null) return null;
    return Uri.parse(template.replaceAll('{txHash}', hash));
  }

  String? _addressTemplate(WalletChainRef chain) {
    switch (chain.id) {
      case 'bsc':
        return 'https://bscscan.com/address/{address}';
      case 'ethereum':
        return 'https://etherscan.io/address/{address}';
      case 'x-layer':
        return 'https://web3.okx.com/explorer/xlayer/address/{address}';
      case 'arbitrum':
        return 'https://arbiscan.io/address/{address}';
      case 'solana':
        return 'https://solscan.io/account/{address}';
      case 'tron':
        return 'https://tronscan.org/#/address/{address}';
    }

    if (chain is WalletChainConfig) {
      return _templateFromConfiguredExplorer(chain.explorerApiUrl);
    }
    return null;
  }

  String? _transactionTemplate(WalletChainRef chain) {
    switch (chain.id) {
      case 'bsc':
        return 'https://bscscan.com/tx/{txHash}';
      case 'ethereum':
        return 'https://etherscan.io/tx/{txHash}';
      case 'x-layer':
        return 'https://web3.okx.com/explorer/xlayer/tx/{txHash}';
      case 'arbitrum':
        return 'https://arbiscan.io/tx/{txHash}';
      case 'solana':
        return 'https://solscan.io/tx/{txHash}';
      case 'tron':
        return 'https://tronscan.org/#/transaction/{txHash}';
    }

    if (chain is WalletChainConfig) {
      return _transactionTemplateFromConfiguredExplorer(chain.explorerApiUrl);
    }
    return null;
  }

  String? _templateFromConfiguredExplorer(String? explorerApiUrl) {
    final rawUrl = explorerApiUrl?.trim() ?? '';
    if (rawUrl.isEmpty) return null;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return null;
    }

    final blockscoutBase = _blockscoutBase(uri);
    if (blockscoutBase != null) {
      return '$blockscoutBase/address/{address}';
    }

    final webHost = uri.host.startsWith('api.')
        ? uri.host.substring(4)
        : uri.host;
    if (_looksLikeEvmScanHost(webHost)) {
      return '${uri.scheme}://$webHost/address/{address}';
    }
    return null;
  }

  String? _transactionTemplateFromConfiguredExplorer(String? explorerApiUrl) {
    final rawUrl = explorerApiUrl?.trim() ?? '';
    if (rawUrl.isEmpty) return null;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return null;
    }

    final blockscoutBase = _blockscoutBase(uri);
    if (blockscoutBase != null) {
      return '$blockscoutBase/tx/{txHash}';
    }

    final webHost = uri.host.startsWith('api.')
        ? uri.host.substring(4)
        : uri.host;
    if (_looksLikeEvmScanHost(webHost)) {
      return '${uri.scheme}://$webHost/tx/{txHash}';
    }
    return null;
  }

  String? _blockscoutBase(Uri uri) {
    final lowerHost = uri.host.toLowerCase();
    final lowerPath = uri.path.toLowerCase();
    if (!lowerHost.contains('blockscout') && !lowerPath.contains('/api/v2')) {
      return null;
    }
    const marker = '/api/v2';
    final markerIndex = lowerPath.indexOf(marker);
    final basePath = markerIndex >= 0
        ? uri.path.substring(0, markerIndex)
        : uri.path;
    final normalizedPath = basePath.replaceAll(RegExp(r'/+$'), '');
    return '${uri.scheme}://${uri.host}$normalizedPath';
  }

  bool _looksLikeEvmScanHost(String host) {
    final lowerHost = host.toLowerCase();
    return lowerHost.contains('etherscan.io') ||
        lowerHost.contains('bscscan.com') ||
        lowerHost.contains('arbiscan.io') ||
        lowerHost.contains('polygonscan.com') ||
        lowerHost.contains('snowtrace.io') ||
        lowerHost.contains('basescan.org') ||
        lowerHost.contains('optimistic.etherscan.io');
  }
}
