/// 首页常用代币身份及其展示元数据。
///
/// 用户添加自定义资产时也可以保存列表之外的动态身份；未选择的资产保持独立
/// 展示，避免仅凭 symbol 把同名仿冒代币合并进主资产。
class WalletCanonicalToken {
  const WalletCanonicalToken({
    required this.id,
    required this.symbol,
    required this.name,
  });

  final String id;
  final String symbol;
  final String name;

  static const values = [
    WalletCanonicalToken(id: 'usdt', symbol: 'USDT', name: 'Tether USD'),
    WalletCanonicalToken(id: 'usdc', symbol: 'USDC', name: 'USD Coin'),
    WalletCanonicalToken(id: 'dai', symbol: 'DAI', name: 'Dai Stablecoin'),
    WalletCanonicalToken(id: 'eth', symbol: 'ETH', name: 'Ethereum'),
    WalletCanonicalToken(id: 'btc', symbol: 'BTC', name: 'Bitcoin'),
    WalletCanonicalToken(id: 'bnb', symbol: 'BNB', name: 'BNB'),
    WalletCanonicalToken(id: 'sol', symbol: 'SOL', name: 'Solana'),
    WalletCanonicalToken(id: 'sui', symbol: 'SUI', name: 'Sui'),
    WalletCanonicalToken(id: 'apt', symbol: 'APT', name: 'Aptos'),
    WalletCanonicalToken(id: 'trx', symbol: 'TRX', name: 'TRON'),
    WalletCanonicalToken(
      id: 'pol',
      symbol: 'POL',
      name: 'Polygon Ecosystem Token',
    ),
    WalletCanonicalToken(id: 'avax', symbol: 'AVAX', name: 'Avalanche'),
  ];

  static WalletCanonicalToken? fromId(String? value) {
    final normalized = normalizeId(value);
    if (normalized == null) return null;
    for (final token in values) {
      if (token.id == normalized) return token;
    }
    return null;
  }

  /// 标准化用户明确选择的首页归类 ID。
  ///
  /// ID 不限定在内置常用代币中，因此未来新增 DAI 等币种也无需修改代码。
  static String? normalizeId(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty ||
        !RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }
}
