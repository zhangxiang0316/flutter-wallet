import '../../../wallet/models/wallet_chain.dart';

class TransferScanAddressParser {
  const TransferScanAddressParser._();

  /// 从扫码内容中提取当前链可用的钱包地址。
  static String? extract(String rawValue, WalletChainConfig? chain) {
    final value = rawValue.trim();
    if (value.isEmpty) return null;

    final chainMatchedAddress = extractByChain(value, chain);
    if (chainMatchedAddress != null) return chainMatchedAddress;

    final uri = Uri.tryParse(value);
    final queryAddress = _extractAddressFromQuery(uri, chain);
    if (queryAddress != null) return queryAddress;

    final pathAddress = _normalizeCandidate(
      uri == null || uri.scheme.isEmpty ? value : uri.path,
    );
    if (pathAddress == null) return null;
    return extractByChain(pathAddress, chain) ?? pathAddress;
  }

  /// 按当前链地址格式从任意文本中提取地址。
  static String? extractByChain(String value, WalletChainConfig? chain) {
    if (chain?.isEvm ?? false) {
      return RegExp(r'0x[a-fA-F0-9]{40}').firstMatch(value)?.group(0);
    }
    if (chain?.type == WalletChainType.bitcoin) {
      return RegExp(
        r'(?<![02-9ac-hj-np-z])bc1q[02-9ac-hj-np-z]{38}(?![02-9ac-hj-np-z])',
        caseSensitive: false,
      ).firstMatch(value)?.group(0);
    }
    if (chain?.type == WalletChainType.sui) {
      return RegExp(r'0x[a-fA-F0-9]{64}').firstMatch(value)?.group(0);
    }
    if (chain?.type == WalletChainType.aptos) {
      return RegExp(
        r'(?<![a-fA-F0-9])0x[a-fA-F0-9]{1,64}(?![a-fA-F0-9])',
      ).firstMatch(value)?.group(0);
    }
    switch (chain?.builtinChain) {
      case WalletChain.bsc:
      case WalletChain.ethereum:
      case WalletChain.xLayer:
      case WalletChain.arbitrum:
        return RegExp(r'0x[a-fA-F0-9]{40}').firstMatch(value)?.group(0);
      case WalletChain.bitcoin:
        return RegExp(
          r'(?<![02-9ac-hj-np-z])bc1q[02-9ac-hj-np-z]{38}(?![02-9ac-hj-np-z])',
          caseSensitive: false,
        ).firstMatch(value)?.group(0);
      case WalletChain.tron:
        return RegExp(r'T[1-9A-HJ-NP-Za-km-z]{33}').firstMatch(value)?.group(0);
      case WalletChain.solana:
        return RegExp(
          r'(?<![1-9A-HJ-NP-Za-km-z])[1-9A-HJ-NP-Za-km-z]{32,44}(?![1-9A-HJ-NP-Za-km-z])',
        ).firstMatch(value)?.group(0);
      case WalletChain.sui:
        return RegExp(r'0x[a-fA-F0-9]{64}').firstMatch(value)?.group(0);
      case WalletChain.aptos:
        return RegExp(
          r'(?<![a-fA-F0-9])0x[a-fA-F0-9]{1,64}(?![a-fA-F0-9])',
        ).firstMatch(value)?.group(0);
      case null:
        return null;
    }
  }

  /// 从 URI query 参数中提取常见地址字段。
  static String? _extractAddressFromQuery(Uri? uri, WalletChainConfig? chain) {
    if (uri == null) return null;
    const keys = ['address', 'to', 'recipient'];
    for (final key in keys) {
      final candidate = _normalizeCandidate(uri.queryParameters[key]);
      if (candidate == null) continue;
      return extractByChain(candidate, chain) ?? candidate;
    }
    return null;
  }

  /// 清理扫码候选文本。
  static String? _normalizeCandidate(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final firstLine = trimmed.split(RegExp(r'\s+')).first.trim();
    final withoutNetwork = firstLine.split('@').first;
    final withoutPath = withoutNetwork.split('/').first;
    final withoutQuery = withoutPath.split('?').first;
    return withoutQuery.isEmpty ? null : withoutQuery;
  }
}
