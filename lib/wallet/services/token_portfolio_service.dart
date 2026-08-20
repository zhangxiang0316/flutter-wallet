import 'package:decimal/decimal.dart';

import '../models/chain_balance.dart';
import '../models/token_portfolio.dart';
import '../models/wallet_asset.dart';
import '../models/wallet_chain.dart';
import 'asset_valuation_service.dart';

/// 将多链余额安全地聚合为首页代币组合。
///
/// 内置注册表资产可以跨链合并；未登记资产使用链和合约生成隔离 ID，避免同名
/// 自定义代币冒充 USDT 等常用资产并污染聚合价值。
class TokenPortfolioService {
  TokenPortfolioService({AssetValuationService? valuationService})
    : _valuationService = valuationService ?? AssetValuationService();

  final AssetValuationService _valuationService;

  static const List<String> commonTokenOrder = [
    'USDT',
    'USDC',
    'ETH',
    'BTC',
    'BNB',
    'SOL',
    'SUI',
    'APT',
    'TRX',
    'POL',
    'AVAX',
  ];

  static final Map<String, _TrustedTokenIdentity> _trustedIdentities =
      _buildTrustedIdentities();

  List<TokenPortfolioItem> build({
    required List<ChainBalance> balances,
    required List<WalletChainConfig> chains,
    Map<String, Decimal> prices = const {},
  }) {
    final groups = <String, _TokenGroupBuilder>{};

    for (final balance in balances) {
      final identity = _identityFor(balance);
      final chain = _chainFor(balance, chains);
      final usdValue = _usdValueFor(balance, identity, prices);
      final group = groups.putIfAbsent(
        identity.id,
        () => _TokenGroupBuilder(identity),
      );
      group.add(
        TokenChainPosition(chain: chain, balance: balance, usdValue: usdValue),
      );
    }

    final result = groups.values.map((group) => group.build()).toList();
    result.sort(_compareItems);
    return result;
  }

  _TokenIdentity _identityFor(ChainBalance balance) {
    final trusted =
        _trustedIdentities[_assetKey(
          balance.chainRef,
          balance.contractAddress,
        )];
    if (trusted != null) {
      return _TokenIdentity(
        id: trusted.canonicalId,
        symbol: trusted.symbol,
        name: trusted.name,
        commonRank: _commonRank(trusted.symbol),
        isTrusted: true,
      );
    }

    final assignedId = WalletCanonicalToken.normalizeId(
      balance.canonicalTokenId,
    );
    if (assignedId != null) {
      final assignedToken = WalletCanonicalToken.fromId(assignedId);
      final assignedSymbol =
          assignedToken?.symbol ?? balance.symbol.trim().toUpperCase();
      return _TokenIdentity(
        id: assignedId,
        symbol: assignedSymbol,
        name:
            assignedToken?.name ??
            (balance.name.trim().isEmpty ? assignedSymbol : balance.name),
        commonRank: _commonRank(assignedSymbol),
        isTrusted: true,
      );
    }

    final symbol = balance.symbol.trim().isEmpty
        ? balance.chainRef.symbol.toUpperCase()
        : balance.symbol.trim().toUpperCase();
    return _TokenIdentity(
      id: 'asset:${_assetKey(balance.chainRef, balance.contractAddress)}:$symbol',
      symbol: symbol,
      name: balance.name.trim().isEmpty ? symbol : balance.name,
      commonRank: _commonRank(symbol),
      isTrusted: false,
    );
  }

  Decimal? _usdValueFor(
    ChainBalance balance,
    _TokenIdentity identity,
    Map<String, Decimal> prices,
  ) {
    if (balance.hasError || !identity.isTrusted) return null;
    final amount = Decimal.tryParse(balance.amount);
    final price =
        _valuationService.priceForSymbol(identity.symbol, prices) ??
        _valuationService.priceForSymbol(balance.symbol, prices);
    if (amount == null || price == null) return null;
    return amount * price;
  }

  WalletChainConfig _chainFor(
    ChainBalance balance,
    List<WalletChainConfig> chains,
  ) {
    for (final chain in chains) {
      if (chain.id == balance.chainId) return chain;
    }
    return balance.chainConfig ?? balance.chain!.config;
  }

  static int _compareItems(TokenPortfolioItem left, TokenPortfolioItem right) {
    final leftValue = left.totalUsdValue;
    final rightValue = right.totalUsdValue;
    if (leftValue != null && rightValue != null) {
      final valueOrder = rightValue.compareTo(leftValue);
      if (valueOrder != 0) return valueOrder;
    } else if (leftValue != null) {
      return -1;
    } else if (rightValue != null) {
      return 1;
    }

    final rankOrder = left.commonRank.compareTo(right.commonRank);
    if (rankOrder != 0) return rankOrder;
    return left.symbol.compareTo(right.symbol);
  }

  static int _commonRank(String symbol) {
    final index = commonTokenOrder.indexOf(symbol.toUpperCase());
    return index < 0 ? commonTokenOrder.length : index;
  }

  static Map<String, _TrustedTokenIdentity> _buildTrustedIdentities() {
    final result = <String, _TrustedTokenIdentity>{};
    for (final asset in WalletAssetRegistry.all) {
      final assignedId = WalletCanonicalToken.normalizeId(
        asset.canonicalTokenId,
      );
      final assignedToken = WalletCanonicalToken.fromId(assignedId);
      final canonicalSymbol =
          assignedToken?.symbol ??
          switch (asset.symbol.toUpperCase()) {
            'BTCB' || 'WBTC' || 'CBBTC' => 'BTC',
            'WETH' => 'ETH',
            final symbol => symbol,
          };
      result[_assetKey(
        asset.chainRef,
        asset.contractAddress,
      )] = _TrustedTokenIdentity(
        canonicalId: assignedId ?? canonicalSymbol.toLowerCase(),
        symbol: canonicalSymbol,
        name: _canonicalName(canonicalSymbol, asset.name),
      );
    }
    return result;
  }

  static String _canonicalName(String symbol, String fallback) {
    return switch (symbol) {
      'BTC' => 'Bitcoin',
      'ETH' => 'Ethereum',
      'USDT' => 'Tether USD',
      'USDC' => 'USD Coin',
      _ => fallback,
    };
  }

  static String _assetKey(WalletChainRef chain, String? contractAddress) {
    final contract = contractAddress?.trim() ?? '';
    final normalizedContract = contract.isEmpty
        ? 'native'
        : chain.isEvm
        ? contract.toLowerCase()
        : contract;
    final networkKey = chain.evmChainId == null
        ? chain.id
        : 'evm:${chain.evmChainId}';
    return '$networkKey:$normalizedContract';
  }
}

class _TokenGroupBuilder {
  _TokenGroupBuilder(this.identity);

  final _TokenIdentity identity;
  final List<TokenChainPosition> positions = [];
  Decimal totalAmount = Decimal.zero;
  Decimal totalUsdValue = Decimal.zero;
  bool hasUsdValue = false;
  String? logoUrl;

  void add(TokenChainPosition position) {
    positions.add(position);
    if (!position.balance.hasError) {
      totalAmount += Decimal.tryParse(position.balance.amount) ?? Decimal.zero;
    }
    final positionValue = position.usdValue;
    if (positionValue != null) {
      totalUsdValue += positionValue;
      hasUsdValue = true;
    }
    final candidateLogo = position.balance.logoUrl?.trim() ?? '';
    if ((logoUrl == null || logoUrl!.isEmpty) && candidateLogo.isNotEmpty) {
      logoUrl = candidateLogo;
    }
  }

  TokenPortfolioItem build() {
    positions.sort(
      (left, right) => left.chain.name.compareTo(right.chain.name),
    );
    return TokenPortfolioItem(
      canonicalTokenId: identity.id,
      symbol: identity.symbol,
      name: identity.name,
      logoUrl: logoUrl,
      positions: List.unmodifiable(positions),
      totalAmount: totalAmount,
      totalUsdValue: hasUsdValue ? totalUsdValue : null,
      commonRank: identity.commonRank,
    );
  }
}

class _TokenIdentity {
  const _TokenIdentity({
    required this.id,
    required this.symbol,
    required this.name,
    required this.commonRank,
    required this.isTrusted,
  });

  final String id;
  final String symbol;
  final String name;
  final int commonRank;
  final bool isTrusted;
}

class _TrustedTokenIdentity {
  const _TrustedTokenIdentity({
    required this.canonicalId,
    required this.symbol,
    required this.name,
  });

  final String canonicalId;
  final String symbol;
  final String name;
}
