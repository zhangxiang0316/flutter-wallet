import 'wallet_chain.dart';

/// WalletChain 类型检查扩展。
///
/// 提供便捷的链类型判断方法，避免在多处重复实现相同的判断逻辑。
extension WalletChainTypeExtension on WalletChainRef {
  /// 判断是否为 TRON 链。
  bool get isTron => id == 'tron';

  /// 判断是否为 Solana 链。
  bool get isSolana => id == 'solana';

  /// 判断是否为 Sui 链。
  bool get isSui =>
      id == 'sui' ||
      (this is WalletChainConfig &&
          (this as WalletChainConfig).type == WalletChainType.sui);

  /// 判断是否为 Aptos 链。
  bool get isAptos =>
      id == 'aptos' ||
      (this is WalletChainConfig &&
          (this as WalletChainConfig).type == WalletChainType.aptos);

  /// 判断是否为 Bitcoin 主网。
  bool get isBitcoin =>
      id == 'bitcoin' ||
      (this is WalletChainConfig &&
          (this as WalletChainConfig).type == WalletChainType.bitcoin);

  /// 判断是否为 EVM 兼容链。
  ///
  /// 包括 BSC、Ethereum、Arbitrum、X Layer、Base 等所有 EVM 链。
  bool get isEvm => evmChainId != null;
}
