import 'package:decimal/decimal.dart';

import '../../../wallet/models/payment_request.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/adapters/chain_adapter_registry.dart';
import '../../../wallet/adapters/default_chain_adapter_registry.dart';

/// 链感知二维码解析器。
class TransferScanAddressParser {
  const TransferScanAddressParser._();

  static final RegExp _amountPattern = RegExp(r'^[0-9]+(?:\.[0-9]+)?$');

  /// 解析付款请求或当前链的纯地址二维码。
  ///
  /// 未知 scheme、缺少必要字段、无效金额或地址格式损坏时返回 null，不再从
  /// 任意 URI/query 中宽松提取地址。
  static PaymentRequest? parse(
    String rawValue,
    WalletChainConfig? currentChain, {
    ChainAdapterRegistry? adapterRegistry,
  }) {
    final registry = adapterRegistry ?? createDefaultChainAdapterRegistry();
    final value = rawValue.trim();
    if (value.isEmpty || value.contains(RegExp(r'[\r\n]'))) return null;

    final plainAddress = _exactAddress(value, currentChain, registry);
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
    if (scheme == 'omnicast') {
      return _parseOmnicast(uri, currentChain, registry);
    }
    if (registry.findByPaymentUriScheme(scheme) == null) return null;
    return _parseNativeUri(uri, scheme, currentChain, registry);
  }

  /// 向后兼容只需要地址的调用方。
  static String? extract(String rawValue, WalletChainConfig? currentChain) {
    return parse(rawValue, currentChain)?.address;
  }

  static PaymentRequest? _parseOmnicast(
    Uri uri,
    WalletChainConfig? currentChain,
    ChainAdapterRegistry adapterRegistry,
  ) {
    if (uri.host.toLowerCase() != 'receive') return null;
    final chainId = _trimmed(uri.queryParameters['chain']);
    final address = _trimmed(uri.queryParameters['address']);
    if (chainId == null || address == null) return null;
    final targetChain = _chainConfigForId(chainId, currentChain);
    if (!_isValidAddress(address, targetChain, chainId, adapterRegistry)) {
      return null;
    }
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
    ChainAdapterRegistry adapterRegistry,
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
    declaredChainId ??= _chainIdForScheme(
      scheme,
      currentChain,
      adapterRegistry,
    );
    final targetChain = _chainConfigForId(declaredChainId, currentChain);
    if (!_isValidAddress(path, targetChain, declaredChainId, adapterRegistry)) {
      return null;
    }
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
      if (!_amountPattern.hasMatch(amount)) return null;
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
  static String? extractByChain(
    String value,
    WalletChainConfig? chain, {
    ChainAdapterRegistry? adapterRegistry,
  }) {
    if (chain == null) return null;
    final registry = adapterRegistry ?? createDefaultChainAdapterRegistry();
    return registry.find(chain)?.extractAddress(value);
  }

  static String? _exactAddress(
    String value,
    WalletChainConfig? chain,
    ChainAdapterRegistry adapterRegistry,
  ) {
    final extracted = extractByChain(
      value,
      chain,
      adapterRegistry: adapterRegistry,
    );
    return extracted == value ? extracted : null;
  }

  static bool _isValidAddress(
    String value,
    WalletChainConfig? chain,
    String? chainId,
    ChainAdapterRegistry adapterRegistry,
  ) {
    if (chain != null) {
      return _exactAddress(value, chain, adapterRegistry) != null;
    }
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
    ChainAdapterRegistry adapterRegistry,
  ) {
    final schemeAdapter = adapterRegistry.findByPaymentUriScheme(scheme);
    if (schemeAdapter == null) return null;
    if (currentChain?.adapterId == schemeAdapter.id) {
      return currentChain!.id;
    }
    for (final chain in WalletChain.values) {
      if (chain.adapterId == schemeAdapter.id) return chain.id;
    }
    return null;
  }

  static String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
