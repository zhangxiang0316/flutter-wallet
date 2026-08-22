import 'package:decimal/decimal.dart';

import '../../../wallet/models/payment_request.dart';
import '../../../wallet/models/wallet_chain.dart';

/// 链感知二维码解析器。
class TransferScanAddressParser {
  const TransferScanAddressParser._();

  static const Set<String> _supportedSchemes = {
    'omnicast',
    'ethereum',
    'tron',
    'solana',
    'bitcoin',
    'sui',
    'aptos',
  };

  /// 解析付款请求或当前链的纯地址二维码。
  ///
  /// 未知 scheme、缺少必要字段、无效金额或地址格式损坏时返回 null，不再从
  /// 任意 URI/query 中宽松提取地址。
  static PaymentRequest? parse(
    String rawValue,
    WalletChainConfig? currentChain,
  ) {
    final value = rawValue.trim();
    if (value.isEmpty || value.contains(RegExp(r'[\r\n]'))) return null;

    final plainAddress = _exactAddress(value, currentChain);
    if (plainAddress != null) {
      return PaymentRequest(
        scheme: '',
        chainId: currentChain?.id,
        address: plainAddress,
        isPlainAddress: true,
      );
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    if (!_supportedSchemes.contains(scheme)) return null;
    if (scheme == 'omnicast') {
      return _parseOmnicast(uri, currentChain);
    }
    return _parseNativeUri(uri, scheme, currentChain);
  }

  /// 向后兼容只需要地址的调用方。
  static String? extract(String rawValue, WalletChainConfig? currentChain) {
    return parse(rawValue, currentChain)?.address;
  }

  static PaymentRequest? _parseOmnicast(
    Uri uri,
    WalletChainConfig? currentChain,
  ) {
    if (uri.host.toLowerCase() != 'receive') return null;
    final chainId = _trimmed(uri.queryParameters['chain']);
    final address = _trimmed(uri.queryParameters['address']);
    if (chainId == null || address == null) return null;
    final targetChain = _chainConfigForId(chainId, currentChain);
    if (!_isValidAddress(address, targetChain, chainId)) return null;
    return _requestFromUri(
      uri: uri,
      scheme: 'omnicast',
      chainId: chainId,
      address: address,
    );
  }

  static PaymentRequest? _parseNativeUri(
    Uri uri,
    String scheme,
    WalletChainConfig? currentChain,
  ) {
    var path = _trimmed(uri.path);
    if (path == null && uri.host.isNotEmpty) path = uri.host;
    path = _trimmed(uri.queryParameters['address']) ?? path;
    if (path == null) return null;

    String? declaredChainId = _trimmed(uri.queryParameters['chain']);
    if (scheme == 'ethereum') {
      final parts = path.split('@');
      if (parts.length > 2) return null;
      path = parts.first;
      if (parts.length == 2) {
        declaredChainId = _evmChainId(parts.last)?.id;
        if (declaredChainId == null) return null;
      }
    }
    declaredChainId ??= _chainIdForScheme(scheme, currentChain);
    final targetChain = _chainConfigForId(declaredChainId, currentChain);
    if (!_isValidAddress(path, targetChain, declaredChainId)) return null;
    return _requestFromUri(
      uri: uri,
      scheme: scheme,
      chainId: declaredChainId,
      address: path,
    );
  }

  static PaymentRequest? _requestFromUri({
    required Uri uri,
    required String scheme,
    required String? chainId,
    required String address,
  }) {
    final amount = _trimmed(uri.queryParameters['amount']);
    if (amount != null) {
      final parsed = Decimal.tryParse(amount);
      if (parsed == null || parsed <= Decimal.zero) return null;
    }
    final memo =
        _trimmed(uri.queryParameters['memo']) ??
        _trimmed(uri.queryParameters['message']) ??
        _trimmed(uri.queryParameters['label']);
    if (memo != null && memo.length > 80) return null;
    return PaymentRequest(
      scheme: scheme,
      chainId: chainId,
      address: address,
      symbol: _trimmed(uri.queryParameters['symbol']),
      contractAddress: _trimmed(uri.queryParameters['contract']),
      amount: amount,
      memo: memo,
    );
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
      case WalletChain.base:
      case WalletChain.polygon:
      case WalletChain.avalanche:
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

  static String? _exactAddress(String value, WalletChainConfig? chain) {
    final extracted = extractByChain(value, chain);
    return extracted == value ? extracted : null;
  }

  static bool _isValidAddress(
    String value,
    WalletChainConfig? chain,
    String? chainId,
  ) {
    if (chain != null) return _exactAddress(value, chain) != null;
    if (chainId != null && chainId.startsWith('evm-')) {
      return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value);
    }
    return false;
  }

  static WalletChainConfig? _chainConfigForId(
    String? chainId,
    WalletChainConfig? currentChain,
  ) {
    if (chainId == null) return currentChain;
    if (currentChain?.id == chainId) return currentChain;
    for (final chain in WalletChain.values) {
      if (chain.id == chainId) return chain.config;
    }
    return null;
  }

  static WalletChainConfig? _evmChainId(String value) {
    final id = int.tryParse(value);
    if (id == null) return null;
    for (final chain in WalletChain.values) {
      if (chain.evmChainId == id) return chain.config;
    }
    return null;
  }

  static String? _chainIdForScheme(
    String scheme,
    WalletChainConfig? currentChain,
  ) {
    switch (scheme) {
      case 'bitcoin':
      case 'tron':
      case 'solana':
      case 'sui':
      case 'aptos':
        return scheme;
      case 'ethereum':
        return currentChain?.isEvm ?? false ? currentChain!.id : null;
      default:
        return null;
    }
  }

  static String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
