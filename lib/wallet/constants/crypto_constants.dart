/// 加密货币相关常量。
///
/// 集中定义加密货币钱包中常用的常量，避免在多个文件中重复定义。
class CryptoConstants {
  CryptoConstants._();

  /// Base58 编码字母表。
  ///
  /// 用于 TRON 和 Solana 地址编码/解码。
  static const String base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  /// EVM 默认派生路径。
  ///
  /// 遵循 BIP44 标准，适用于 BSC、Ethereum、Arbitrum 等 EVM 链。
  static const String evmDerivationPath = "m/44'/60'/0'/0/0";

  /// Solana 默认派生路径。
  ///
  /// 遵循 BIP44 标准，使用 Ed25519 hardened derivation。
  static const String solanaDerivationPath = "m/44'/501'/0'/0'";

  /// EVM 原生币转账固定 gas limit。
  static const int evmNativeGasLimit = 21000;

  /// EVM ERC20 转账兜底 gas limit。
  static const int evmTokenGasLimit = 100000;

  /// TRC20 转账 fee_limit，单位 sun。
  static const int tronTokenFeeLimit = 30 * 1000 * 1000;

  /// Solana 单签名基础费用，单位 lamports。
  static const int solanaLamportsPerSignature = 5000;

  /// secp256k1 素数域 p。
  ///
  /// 用于 ECDSA public key 恢复验证。
  static final secp256k1P = BigInt.parse(
    'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
    radix: 16,
  );

  /// EVM Transfer 事件的 topic。
  static const String evmTransferEventTopic =
      '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';
}
