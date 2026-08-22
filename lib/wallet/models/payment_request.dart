/// 链感知付款请求。
///
/// 该模型只保存二维码声明的内容，不代表请求已经通过当前钱包的链、资产或地址
/// 校验。转账页面必须完成匹配和用户确认后才能应用这些字段。
class PaymentRequest {
  const PaymentRequest({
    required this.scheme,
    required this.address,
    this.chainId,
    this.symbol,
    this.contractAddress,
    this.amount,
    this.memo,
    this.isPlainAddress = false,
  });

  /// URI scheme；纯地址二维码为空字符串。
  final String scheme;

  /// 应用内链 ID，例如 `polygon`、`tron` 或 `solana`。
  final String? chainId;

  final String address;
  final String? symbol;
  final String? contractAddress;
  final String? amount;
  final String? memo;

  /// 是否来自不携带协议和链信息的纯地址二维码。
  final bool isPlainAddress;

  /// 编码为应用内链感知收款 URI。
  Uri toUri() {
    final requestChainId = chainId?.trim() ?? '';
    if (requestChainId.isEmpty || address.trim().isEmpty) {
      throw const FormatException('Payment request requires chain and address');
    }
    return Uri(
      scheme: scheme.isEmpty ? 'omnicast' : scheme,
      host: 'receive',
      queryParameters: {
        'address': address.trim(),
        'chain': requestChainId,
        if (_notEmpty(symbol)) 'symbol': symbol!.trim(),
        if (_notEmpty(contractAddress)) 'contract': contractAddress!.trim(),
        if (_notEmpty(amount)) 'amount': amount!.trim(),
        if (_notEmpty(memo)) 'memo': memo!.trim(),
      },
    );
  }

  static bool _notEmpty(String? value) => value?.trim().isNotEmpty ?? false;
}
