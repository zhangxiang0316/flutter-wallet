import 'package:decimal/decimal.dart';

import 'chain_balance.dart';
import 'wallet_chain.dart';

/// 同一可信代币在某条链上的余额和估值。
class TokenChainPosition {
  const TokenChainPosition({
    required this.chain,
    required this.balance,
    required this.usdValue,
  });

  final WalletChainConfig chain;
  final ChainBalance balance;
  final Decimal? usdValue;
}

/// 首页按代币聚合后的只读展示模型。
///
/// [positions] 保留原始 [ChainBalance]，详情页进入交易记录时仍能准确定位链和
/// 合约；本模型不参与余额缓存或转账签名。
class TokenPortfolioItem {
  const TokenPortfolioItem({
    required this.canonicalTokenId,
    required this.symbol,
    required this.name,
    required this.logoUrl,
    required this.positions,
    required this.totalAmount,
    required this.totalUsdValue,
    required this.commonRank,
  });

  final String canonicalTokenId;
  final String symbol;
  final String name;
  final String? logoUrl;
  final List<TokenChainPosition> positions;
  final Decimal totalAmount;
  final Decimal? totalUsdValue;
  final int commonRank;

  bool get hasPartialError =>
      positions.any((position) => position.balance.hasError);
}
