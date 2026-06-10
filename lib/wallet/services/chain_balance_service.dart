import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:solana/solana.dart';

import '../models/chain_balance.dart';
import '../models/wallet_asset.dart';
import '../models/wallet_chain.dart';
import 'wallet_custom_asset_service.dart';

/// 多链余额查询服务。
///
/// 首页资产列表依赖该服务一次性查询所有支持链的余额。当前支持：
/// - BNB Smart Chain / Ethereum / X Layer：通过 EVM JSON-RPC 查询原生币和 ERC20；
/// - Solana：通过 Solana JSON-RPC 查询 SOL 和 SPL Token；
/// - TRON：通过 TRON 节点接口查询 TRX 和 TRC20。
///
/// 该服务尽量不向 UI 抛出单个资产查询异常。某个资产查询失败时，会返回 amount=0
/// 且带上 error 字段，保证首页仍能展示其它链和其它币种的余额。
class ChainBalanceService {
  /// 创建余额查询服务。
  ///
  /// 测试时可以传入自定义 [Dio] 或 [WalletCustomAssetService]；业务场景默认使用
  /// 内置 Dio 和用户自定义资产服务。
  ChainBalanceService({Dio? dio, WalletCustomAssetService? customAssetService})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: _requestTimeout,
              receiveTimeout: _requestTimeout,
              sendTimeout: _requestTimeout,
            ),
          ),
      _customAssetService = customAssetService ?? WalletCustomAssetService();

  /// RPC/HTTP 请求客户端。
  final Dio _dio;

  /// 用户自定义资产服务，用于把用户添加的代币合并进默认查询列表。
  final WalletCustomAssetService _customAssetService;

  /// 常规链 RPC 请求超时时间。
  static const Duration _requestTimeout = Duration(seconds: 12);

  /// Solana 单次 RPC 请求超时时间。
  ///
  /// Solana 公共节点偶尔响应较慢，单次请求设置得更短，避免拖慢整个首页刷新。
  static const Duration _solanaRequestTimeout = Duration(seconds: 6);

  /// Solana 整条链余额查询的总超时时间。
  ///
  /// 超时后会返回 Solana 资产的 0 余额兜底列表，避免页面一直 loading。
  static const Duration _solanaChainTimeout = Duration(seconds: 14);

  /// EVM 链 RPC 备用节点。
  ///
  /// 每条 EVM 链按顺序尝试节点，前一个失败后自动切到下一个。
  static const Map<WalletChain, List<String>> _evmRpcFallbacks = {
    WalletChain.bsc: [
      'https://bsc-dataseed.bnbchain.org',
      'https://bsc-rpc.publicnode.com',
    ],
    WalletChain.ethereum: [
      'https://ethereum-rpc.publicnode.com',
      'https://eth.llamarpc.com',
    ],
    WalletChain.xLayer: [
      'https://rpc.xlayer.tech',
      'https://xlayerrpc.okx.com',
    ],
  };

  /// TRON 账号查询备用节点。
  static const List<String> _tronRpcFallbacks = [
    'https://api.trongrid.io',
    'https://tron-rpc.publicnode.com',
  ];

  /// Solana JSON-RPC 备用节点。
  static const List<String> _solanaRpcFallbacks = [
    'https://api.mainnet-beta.solana.com',
    'https://solana-rpc.publicnode.com',
  ];

  /// Solana SPL Token Program 地址。
  ///
  /// USDT、USDC 等主流稳定币都使用该 program。按 mint 查询失败时，会用该
  /// program 兜底拉取 owner 下的 token account。
  static const String _solanaTokenProgramId =
      'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';

  /// 查询当前钱包在所有支持链上的资产余额。
  ///
  /// [bscAddress] 实际代表 EVM 地址，BSC、Ethereum、X Layer 共用它；
  /// [tronAddress] 和 [solanaAddress] 分别用于 TRON 和 Solana。
  /// 各链并发查询，最终把多链结果拍平成一个 [ChainBalance] 列表。
  Future<List<ChainBalance>> loadBalances({
    required String bscAddress,
    required String tronAddress,
    required String solanaAddress,
  }) async {
    final customAssets = await _customAssetService.loadCustomAssets();
    final results = await Future.wait([
      _loadEvmBalances(
        chain: WalletChain.bsc,
        assets: WalletAssetRegistry.mergeCustomAssets(
          WalletChain.bsc,
          customAssets,
        ),
        address: bscAddress,
      ),
      _loadEvmBalances(
        chain: WalletChain.ethereum,
        assets: WalletAssetRegistry.mergeCustomAssets(
          WalletChain.ethereum,
          customAssets,
        ),
        address: bscAddress,
      ),
      _loadEvmBalances(
        chain: WalletChain.xLayer,
        assets: WalletAssetRegistry.mergeCustomAssets(
          WalletChain.xLayer,
          customAssets,
        ),
        address: bscAddress,
      ),
      _loadSolanaBalances(solanaAddress, customAssets).timeout(
        _solanaChainTimeout,
        onTimeout: () {
          const error = 'Solana balance lookup timed out';
          developer.log(
            '$error; using zero fallback balances',
            name: 'ChainBalanceService',
          );
          return _fallbackSolanaBalances(
            solanaAddress,
            customAssets,
            error: error,
          );
        },
      ),
      _loadTronBalances(tronAddress, customAssets),
    ]);
    final balances = results.expand((items) => items).toList();
    _printLoadedBalances(results, balances);
    return balances;
  }

  /// 向 EVM 链发送 JSON-RPC 请求。
  ///
  /// 该方法统一处理多 RPC fallback、错误响应识别和日志记录。只有响应中存在
  ///字符串类型的 `result` 时才视为成功。
  Future<Map<dynamic, dynamic>> _postEvmRpc({
    required WalletChain chain,
    required Map<String, dynamic> data,
  }) async {
    Object? lastError;
    for (final rpcUrl in _evmRpcUrls(chain)) {
      try {
        final response = await _dio.post(
          rpcUrl,
          data: data,
          options: Options(headers: {'content-type': 'application/json'}),
        );
        final responseData = response.data;
        if (responseData is Map && responseData['result'] is String) {
          return responseData;
        }
        if (responseData is Map && responseData['error'] != null) {
          throw StateError('${chain.name} RPC error: ${responseData['error']}');
        }
        throw StateError('Invalid ${chain.name} RPC response');
      } catch (error) {
        lastError = error;
        developer.log(
          '${chain.name} RPC request failed at $rpcUrl: $error',
          name: 'ChainBalanceService',
        );
      }
    }
    throw StateError(
      '${chain.name} RPC request failed: ${lastError ?? 'unknown error'}',
    );
  }

  /// 返回某条 EVM 链可用的 RPC 地址列表。
  List<String> _evmRpcUrls(WalletChain chain) {
    return _evmRpcFallbacks[chain] ?? [chain.rpcUrl];
  }

  /// 查询 TRON 账号基础信息。
  ///
  /// 返回数据里包含 TRX 原生余额。TRC20 列表使用另一个 HTTP API 查询。
  Future<Map<dynamic, dynamic>> _postTronAccount(String address) async {
    Object? lastError;
    for (final rpcUrl in _tronRpcFallbacks) {
      try {
        final response = await _dio.post(
          '$rpcUrl/wallet/getaccount',
          data: {'address': address, 'visible': true},
          options: Options(headers: {'content-type': 'application/json'}),
        );
        final responseData = response.data;
        if (responseData is Map) {
          if (responseData['Error'] != null || responseData['error'] != null) {
            throw StateError(
              'TRON RPC error: ${responseData['Error'] ?? responseData['error']}',
            );
          }
          return responseData;
        }
        throw StateError('Invalid TRON response');
      } catch (error) {
        lastError = error;
        developer.log(
          'TRON account request failed at $rpcUrl: $error',
          name: 'ChainBalanceService',
        );
      }
    }
    throw StateError(
      'TRON account request failed: ${lastError ?? 'unknown error'}',
    );
  }

  /// 向 Solana 节点发送 JSON-RPC 请求。
  ///
  /// Solana 使用更短的单请求超时，并在多个公共节点之间 fallback。
  Future<Map<dynamic, dynamic>> _postSolanaRpc({
    required Map<String, dynamic> data,
    bool Function(Object? error)? returnErrorWhen,
  }) async {
    Object? lastError;
    for (final rpcUrl in _solanaRpcFallbacks) {
      try {
        final response = await _dio.post(
          rpcUrl,
          data: data,
          options: Options(
            headers: {'content-type': 'application/json'},
            connectTimeout: _solanaRequestTimeout,
            sendTimeout: _solanaRequestTimeout,
            receiveTimeout: _solanaRequestTimeout,
          ),
        );
        final responseData = response.data;
        if (responseData is Map && responseData['result'] != null) {
          return responseData;
        }
        if (responseData is Map && responseData['error'] != null) {
          final rpcError = responseData['error'];
          if (returnErrorWhen?.call(rpcError) ?? false) {
            return responseData;
          }
          throw StateError('Solana RPC error: $rpcError');
        }
        throw StateError('Invalid Solana RPC response');
      } catch (error) {
        lastError = error;
        final method = data['method']?.toString() ?? 'unknown';
        developer.log(
          'Solana RPC $method request failed at $rpcUrl: $error',
          name: 'ChainBalanceService',
        );
      }
    }
    throw StateError(
      'Solana RPC request failed: ${lastError ?? 'unknown error'}',
    );
  }

  /// 打印本次余额加载的详细日志。
  ///
  /// 用于排查“某条链一直 loading”或“某个币种余额不对”的问题，会输出每条链、
  /// 每个币种的数量、精度、合约地址和错误信息。
  void _printLoadedBalances(
    List<List<ChainBalance>> chainResults,
    List<ChainBalance> balances,
  ) {
    final buffer = StringBuffer()
      ..writeln('----- ChainBalanceService.loadBalances -----')
      ..writeln('total=${balances.length}');

    for (final chainBalances in chainResults) {
      final chainName = chainBalances.isEmpty
          ? 'empty'
          : chainBalances.first.chain.name;
      buffer.writeln('[$chainName] count=${chainBalances.length}');
      for (final balance in chainBalances) {
        buffer.writeln(
          '  ${balance.symbol} amount=${balance.amount} '
          'decimals=${balance.decimals} native=${balance.isNative} '
          'contract=${balance.contractAddress ?? '-'} '
          'error=${balance.error ?? '-'}',
        );
      }
    }

    developer.log(buffer.toString(), name: 'ChainBalanceService');
  }

  /// 查询某条 EVM 链下所有默认资产和自定义资产余额。
  Future<List<ChainBalance>> _loadEvmBalances({
    required WalletChain chain,
    required List<WalletAsset> assets,
    required String address,
  }) async {
    return Future.wait(
      assets.map(
        (asset) => _loadEvmAsset(chain: chain, asset: asset, address: address),
      ),
    );
  }

  /// 根据资产类型分发到原生币或 ERC20 查询逻辑。
  Future<ChainBalance> _loadEvmAsset({
    required WalletChain chain,
    required WalletAsset asset,
    required String address,
  }) async {
    if (asset.isNative) {
      return _loadEvmNativeBalance(
        chain: chain,
        asset: asset,
        address: address,
      );
    }
    return _loadEvmTokenBalance(chain: chain, asset: asset, address: address);
  }

  /// 查询 EVM 原生币余额。
  ///
  /// 使用 `eth_getBalance` 获取最小单位数量（wei），再按资产 decimals 格式化。
  Future<ChainBalance> _loadEvmNativeBalance({
    required WalletChain chain,
    required WalletAsset asset,
    required String address,
  }) async {
    try {
      final data = await _postEvmRpc(
        chain: chain,
        data: {
          'jsonrpc': '2.0',
          'method': 'eth_getBalance',
          'params': [address, 'latest'],
          'id': 1,
        },
      );
      final wei = _parseHexQuantity(data['result'] as String);
      return ChainBalance(
        chain: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(wei, asset.decimals),
        address: address,
        decimals: asset.decimals,
      );
    } catch (e) {
      return ChainBalance(
        chain: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        decimals: asset.decimals,
        error: e.toString(),
      );
    }
  }

  /// 查询 EVM ERC20 代币余额。
  ///
  /// 使用 `eth_call` 调用 ERC20 `balanceOf(address)`，不需要发交易或消耗 gas。
  Future<ChainBalance> _loadEvmTokenBalance({
    required WalletChain chain,
    required WalletAsset asset,
    required String address,
  }) async {
    try {
      final data = await _postEvmRpc(
        chain: chain,
        data: {
          'jsonrpc': '2.0',
          'method': 'eth_call',
          'params': [
            {'to': asset.contractAddress, 'data': erc20BalanceOfData(address)},
            'latest',
          ],
          'id': 1,
        },
      );
      final value = _parseHexQuantity(data['result'] as String);
      return ChainBalance(
        chain: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(value, asset.decimals),
        address: address,
        contractAddress: asset.contractAddress,
        decimals: asset.decimals,
      );
    } catch (e) {
      return ChainBalance(
        chain: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        contractAddress: asset.contractAddress,
        decimals: asset.decimals,
        error: e.toString(),
      );
    }
  }

  /// 查询 TRON 链余额。
  ///
  /// TRX 原生余额和 TRC20 余额走不同接口。返回时会保证已知代币都在列表中：
  /// 没查到的已知代币补 0，接口返回但资产表未知的 TRC20 也保留展示。
  Future<List<ChainBalance>> _loadTronBalances(
    String address,
    List<WalletAsset> customAssets,
  ) async {
    final nativeBalance = await _loadTronNativeBalance(address);
    final tokenBalances = await _loadTronTokenBalances(address, customAssets);
    final tokenMap = {
      for (final balance in tokenBalances)
        if (balance.contractAddress != null) balance.contractAddress!: balance,
    };
    final knownTokens =
        WalletAssetRegistry.mergeCustomAssets(
          WalletChain.tron,
          customAssets,
        ).where((asset) => !asset.isNative).map((asset) {
          return tokenMap[asset.contractAddress] ??
              ChainBalance(
                chain: WalletChain.tron,
                symbol: asset.symbol,
                name: asset.name,
                amount: '0',
                address: address,
                contractAddress: asset.contractAddress,
                decimals: asset.decimals,
              );
        });
    final unknownTokens = tokenBalances.where((balance) {
      final contractAddress = balance.contractAddress;
      return contractAddress != null &&
          WalletAssetRegistry.findAssetByContract(
                WalletChain.tron,
                contractAddress,
                customAssets: customAssets,
              ) ==
              null;
    });
    return [nativeBalance, ...knownTokens, ...unknownTokens];
  }

  /// 查询 Solana 链余额。
  ///
  /// 空地址直接返回 0 余额兜底。正常情况下会并发查询 SOL 原生余额和当前配置的
  /// SPL Token 余额。
  Future<List<ChainBalance>> _loadSolanaBalances(
    String address,
    List<WalletAsset> customAssets,
  ) async {
    if (address.trim().isEmpty) {
      return _fallbackSolanaBalances(address, customAssets);
    }

    final solanaAssets = WalletAssetRegistry.mergeCustomAssets(
      WalletChain.solana,
      customAssets,
    );
    final tokenAssets = solanaAssets
        .where((asset) => !asset.isNative)
        .toList(growable: false);
    final nativeBalanceFuture = _loadSolanaNativeBalance(address);
    final tokenBalancesFuture = _loadSolanaTokenBalances(address, tokenAssets);
    final nativeBalance = await nativeBalanceFuture;
    final tokenBalances = await tokenBalancesFuture;
    return [nativeBalance, ...tokenBalances];
  }

  /// 构造 Solana 资产的 0 余额兜底列表。
  ///
  /// 用于 Solana 地址缺失、RPC 超时或整链查询不可用时，保证 UI 仍有稳定结构。
  List<ChainBalance> _fallbackSolanaBalances(
    String address,
    List<WalletAsset> customAssets, {
    String? error,
  }) {
    return WalletAssetRegistry.mergeCustomAssets(
          WalletChain.solana,
          customAssets,
        )
        .map(
          (asset) => ChainBalance(
            chain: WalletChain.solana,
            symbol: asset.symbol,
            name: asset.name,
            amount: '0',
            address: address,
            contractAddress: asset.contractAddress,
            decimals: asset.decimals,
            error: error,
          ),
        )
        .toList(growable: false);
  }

  /// 查询 SOL 原生余额。
  ///
  /// Solana 节点返回 lamports，需要按 SOL 的 decimals 转换成人类可读数量。
  Future<ChainBalance> _loadSolanaNativeBalance(String address) async {
    final asset = WalletAssetRegistry.solanaAssets.first;
    try {
      final data = await _postSolanaRpc(
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getBalance',
          'params': [address],
        },
      );
      final result = data['result'];
      final value = result is Map ? result['value'] : null;
      final lamports = value is int
          ? BigInt.from(value)
          : BigInt.tryParse(value?.toString() ?? '0') ?? BigInt.zero;
      return ChainBalance(
        chain: WalletChain.solana,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(lamports, asset.decimals),
        address: address,
        decimals: asset.decimals,
      );
    } catch (e) {
      developer.log(
        'Solana native balance failed; using zero fallback: $e',
        name: 'ChainBalanceService',
      );
      return ChainBalance(
        chain: WalletChain.solana,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        decimals: asset.decimals,
        error: e.toString(),
      );
    }
  }

  /// 查询单个 Solana SPL Token 余额。
  ///
  /// 默认优先计算 ATA 并调用 `getTokenAccountBalance` 直查余额。这个接口不需要
  /// 扫描 owner 下的账户，公共节点兼容性比 `getTokenAccountsByOwner` 更好。
  Future<ChainBalance> _loadSolanaTokenBalance(
    String address,
    WalletAsset asset,
  ) async {
    try {
      return await _loadSolanaAssociatedTokenBalance(address, asset);
    } catch (e) {
      developer.log(
        'Solana ${asset.symbol} ATA balance failed; falling back to owner lookup: $e',
        name: 'ChainBalanceService',
      );
      return _loadSolanaTokenBalanceByOwner(address, asset);
    }
  }

  /// 通过 Solana ATA 地址直接查询 SPL Token 余额。
  ///
  /// ATA 未创建时，链上会返回 account not found，这代表该币种余额为 0，不应当标记
  /// 为查询失败。
  Future<ChainBalance> _loadSolanaAssociatedTokenBalance(
    String address,
    WalletAsset asset,
  ) async {
    final contractAddress = asset.contractAddress;
    if (contractAddress == null || contractAddress.trim().isEmpty) {
      return _zeroSolanaTokenBalance(address, asset);
    }

    final owner = Ed25519HDPublicKey.fromBase58(address);
    final mint = Ed25519HDPublicKey.fromBase58(contractAddress);
    final tokenAccount = await findAssociatedTokenAddress(
      owner: owner,
      mint: mint,
    );
    final data = await _postSolanaRpc(
      data: {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'getTokenAccountBalance',
        'params': [tokenAccount.toBase58()],
      },
      returnErrorWhen: _isSolanaTokenAccountNotFoundError,
    );
    if (data['error'] != null) {
      return _zeroSolanaTokenBalance(address, asset);
    }

    final result = data['result'];
    final value = result is Map ? result['value'] : null;
    if (value is! Map) {
      throw StateError('Invalid Solana ${asset.symbol} token account balance');
    }
    final rawAmount = BigInt.tryParse(value['amount']?.toString() ?? '');
    if (rawAmount == null) {
      throw StateError('Invalid Solana ${asset.symbol} token amount');
    }
    final decimalsValue = value['decimals'];
    final decimals = decimalsValue is int
        ? decimalsValue
        : int.tryParse(decimalsValue?.toString() ?? '') ?? asset.decimals;
    return ChainBalance(
      chain: WalletChain.solana,
      symbol: asset.symbol,
      name: asset.name,
      amount: _formatUnits(rawAmount, decimals),
      address: address,
      contractAddress: asset.contractAddress,
      decimals: decimals,
    );
  }

  /// 通过 owner + mint 扫描 token account 查询 SPL Token 余额。
  ///
  /// 该路径只作为 ATA 直查失败后的兜底。接口返回的是最小单位字符串，需要按
  /// decimals 格式化。
  Future<ChainBalance> _loadSolanaTokenBalanceByOwner(
    String address,
    WalletAsset asset,
  ) async {
    try {
      final data = await _postSolanaRpc(
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getTokenAccountsByOwner',
          'params': [
            address,
            {'mint': asset.contractAddress},
            {'encoding': 'jsonParsed'},
          ],
        },
      );
      final result = data['result'];
      final values = result is Map ? result['value'] : null;
      if (values is! List) {
        throw StateError('Invalid Solana ${asset.symbol} token response');
      }

      var rawAmountTotal = BigInt.zero;
      var decimals = asset.decimals;
      for (final item in values) {
        final account = item is Map ? item['account'] : null;
        final accountData = account is Map ? account['data'] : null;
        final parsed = accountData is Map ? accountData['parsed'] : null;
        final info = parsed is Map ? parsed['info'] : null;
        if (info is! Map) continue;

        final mint = info['mint']?.toString();
        if (mint != asset.contractAddress) continue;

        final tokenAmount = info['tokenAmount'];
        final decimalsValue = tokenAmount is Map ? tokenAmount['decimals'] : 0;
        decimals = decimalsValue is int
            ? decimalsValue
            : int.tryParse(decimalsValue?.toString() ?? '') ?? asset.decimals;
        final rawAmount = tokenAmount is Map
            ? tokenAmount['amount']?.toString()
            : null;
        rawAmountTotal += BigInt.tryParse(rawAmount ?? '0') ?? BigInt.zero;
      }
      return ChainBalance(
        chain: WalletChain.solana,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(rawAmountTotal, decimals),
        address: address,
        contractAddress: asset.contractAddress,
        decimals: decimals,
      );
    } catch (e) {
      developer.log(
        'Solana ${asset.symbol} balance failed; using zero fallback: $e',
        name: 'ChainBalanceService',
      );
      return ChainBalance(
        chain: WalletChain.solana,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        contractAddress: asset.contractAddress,
        decimals: asset.decimals,
        error: e.toString(),
      );
    }
  }

  /// 构造 Solana token 的 0 余额记录。
  ChainBalance _zeroSolanaTokenBalance(String address, WalletAsset asset) {
    return ChainBalance(
      chain: WalletChain.solana,
      symbol: asset.symbol,
      name: asset.name,
      amount: '0',
      address: address,
      contractAddress: asset.contractAddress,
      decimals: asset.decimals,
    );
  }

  /// 判断 Solana RPC 错误是否代表 ATA 尚未创建。
  bool _isSolanaTokenAccountNotFoundError(Object? error) {
    final message = error is Map
        ? error['message']?.toString().toLowerCase()
        : error?.toString().toLowerCase();
    return message != null &&
        (message.contains('could not find account') ||
            message.contains('account not found') ||
            (message.contains('invalid param') && message.contains('account')));
  }

  /// 查询 Solana 钱包下所有 SPL Token 余额。
  ///
  /// 默认先按 mint 分别查询 USDT、USDC 等已配置资产，这是 Solana 公共节点最轻量
  /// 且兼容性最好的路径。只有某些 mint 查询失败时，才按 Token Program 拉取当前
  /// owner 的全部 token account 作为兜底，再按 mint 本地汇总。
  Future<List<ChainBalance>> _loadSolanaTokenBalances(
    String address,
    List<WalletAsset> assets,
  ) async {
    if (assets.isEmpty) {
      return [];
    }

    final perMintBalances = await Future.wait(
      assets.map((asset) => _loadSolanaTokenBalance(address, asset)),
    );
    final failedIndexes = <int>[];
    for (var index = 0; index < perMintBalances.length; index++) {
      if (perMintBalances[index].hasError) {
        failedIndexes.add(index);
      }
    }
    if (failedIndexes.isEmpty) {
      return perMintBalances;
    }

    try {
      final tokenAccounts = await _loadSolanaTokenAccountsByOwner(address);
      final nextBalances = [...perMintBalances];
      for (final index in failedIndexes) {
        final asset = assets[index];
        nextBalances[index] = _buildSolanaTokenBalance(
          address,
          asset,
          tokenAccounts,
        );
      }
      return nextBalances;
    } catch (e) {
      developer.log(
        'Solana token account list fallback failed: $e',
        name: 'ChainBalanceService',
      );
      return perMintBalances;
    }
  }

  /// 拉取当前 Solana 地址持有的全部 SPL Token account，并按 mint 汇总。
  Future<Map<String, _SolanaTokenBalance>> _loadSolanaTokenAccountsByOwner(
    String address,
  ) async {
    final data = await _postSolanaRpc(
      data: {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'getTokenAccountsByOwner',
        'params': [
          address,
          {'programId': _solanaTokenProgramId},
          {'encoding': 'jsonParsed'},
        ],
      },
    );
    final result = data['result'];
    final values = result is Map ? result['value'] : null;
    if (values is! List) {
      throw StateError('Invalid Solana token accounts response');
    }

    final balances = <String, _SolanaTokenBalance>{};
    for (final item in values) {
      final parsed = _solanaParsedAccountData(item);
      final info = parsed is Map ? parsed['info'] : null;
      if (info is! Map) continue;

      final mint = info['mint']?.toString();
      if (mint == null || mint.isEmpty) continue;

      final tokenAmount = info['tokenAmount'];
      final rawAmount = tokenAmount is Map
          ? BigInt.tryParse(tokenAmount['amount']?.toString() ?? '')
          : null;
      if (rawAmount == null) continue;

      final decimalsValue = tokenAmount is Map ? tokenAmount['decimals'] : null;
      final decimals = decimalsValue is int
          ? decimalsValue
          : int.tryParse(decimalsValue?.toString() ?? '') ?? 0;
      final current = balances[mint];
      balances[mint] = _SolanaTokenBalance(
        rawAmount: (current?.rawAmount ?? BigInt.zero) + rawAmount,
        decimals: current?.decimals ?? decimals,
      );
    }
    return balances;
  }

  /// 根据已汇总的 Solana token account 余额构造单个资产余额。
  ChainBalance _buildSolanaTokenBalance(
    String address,
    WalletAsset asset,
    Map<String, _SolanaTokenBalance> tokenAccounts,
  ) {
    final tokenBalance = tokenAccounts[asset.contractAddress];
    final decimals = tokenBalance?.decimals ?? asset.decimals;
    return ChainBalance(
      chain: WalletChain.solana,
      symbol: asset.symbol,
      name: asset.name,
      amount: _formatUnits(tokenBalance?.rawAmount ?? BigInt.zero, decimals),
      address: address,
      contractAddress: asset.contractAddress,
      decimals: decimals,
    );
  }

  /// 从 Solana token account 响应项中提取 jsonParsed 的 parsed 数据。
  Map<dynamic, dynamic>? _solanaParsedAccountData(dynamic item) {
    final account = item is Map ? item['account'] : null;
    final accountData = account is Map ? account['data'] : null;
    final parsed = accountData is Map ? accountData['parsed'] : null;
    return parsed is Map ? parsed : null;
  }

  /// 查询 TRX 原生余额。
  ///
  /// TRON 账号接口返回的 balance 单位是 sun，需要按 TRX decimals 转换。
  Future<ChainBalance> _loadTronNativeBalance(String address) async {
    final asset = WalletAssetRegistry.tronAssets.first;
    try {
      final data = await _postTronAccount(address);
      final balance = data['balance'];
      final sun = balance is int
          ? BigInt.from(balance)
          : BigInt.tryParse(balance?.toString() ?? '0') ?? BigInt.zero;
      return ChainBalance(
        chain: WalletChain.tron,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(sun, asset.decimals),
        address: address,
        decimals: asset.decimals,
      );
    } catch (e) {
      return ChainBalance(
        chain: WalletChain.tron,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        decimals: asset.decimals,
        error: e.toString(),
      );
    }
  }

  /// 查询 TRON TRC20 余额列表。
  ///
  /// TRONGrid 账号接口会返回账号持有的 TRC20 合约和原始余额。已知合约会映射成
  /// 资产名称和 decimals；未知合约保留为 `TRC20`，方便后续用户添加自定义资产。
  Future<List<ChainBalance>> _loadTronTokenBalances(
    String address,
    List<WalletAsset> customAssets,
  ) async {
    try {
      final response = await _dio.get(
        '${WalletChain.tron.rpcUrl}/v1/accounts/$address',
        options: Options(headers: {'content-type': 'application/json'}),
      );
      final data = response.data;
      if (data is! Map ||
          data['data'] is! List ||
          (data['data'] as List).isEmpty) {
        return [];
      }
      final account = (data['data'] as List).first;
      if (account is! Map || account['trc20'] is! List) {
        return [];
      }
      final balances = <ChainBalance>[];
      for (final item in account['trc20'] as List) {
        if (item is! Map || item.isEmpty) continue;
        final contractAddress = item.keys.first.toString();
        final rawValue = item.values.first.toString();
        final asset = WalletAssetRegistry.findAssetByContract(
          WalletChain.tron,
          contractAddress,
          customAssets: customAssets,
        );
        final decimals = asset?.decimals ?? 6;
        balances.add(
          ChainBalance(
            chain: WalletChain.tron,
            symbol: asset?.symbol ?? 'TRC20',
            name: asset?.name ?? contractAddress,
            amount: _formatUnits(
              BigInt.tryParse(rawValue) ?? BigInt.zero,
              decimals,
            ),
            address: address,
            contractAddress: contractAddress,
            decimals: decimals,
          ),
        );
      }
      return balances;
    } catch (_) {
      return WalletAssetRegistry.mergeCustomAssets(
            WalletChain.tron,
            customAssets,
          )
          .where((asset) => !asset.isNative)
          .map(
            (asset) => ChainBalance(
              chain: WalletChain.tron,
              symbol: asset.symbol,
              name: asset.name,
              amount: '0',
              address: address,
              contractAddress: asset.contractAddress,
              decimals: asset.decimals,
              error: 'TRC20 balance lookup failed',
            ),
          )
          .toList();
    }
  }

  /// 生成 ERC20 `balanceOf(address)` 调用数据。
  ///
  /// `0x70a08231` 是 `balanceOf(address)` 的 4 字节方法选择器，后面拼接 32 字节
  /// 左侧补零的地址参数。
  static String erc20BalanceOfData(String address) {
    final cleanAddress = address.replaceFirst('0x', '').toLowerCase();
    return '0x70a08231${cleanAddress.padLeft(64, '0')}';
  }

  /// 解析 EVM JSON-RPC 返回的十六进制数量。
  BigInt _parseHexQuantity(String value) {
    final cleanValue = value.replaceFirst('0x', '');
    if (cleanValue.isEmpty) {
      return BigInt.zero;
    }
    return BigInt.parse(cleanValue, radix: 16);
  }

  /// 将链上最小单位整数格式化为十进制资产数量。
  ///
  /// 例如 wei/sun/lamports/token raw amount 都会通过该方法按 decimals 转成人类可读
  /// 字符串，并去掉末尾多余的 0。
  String _formatUnits(BigInt value, int decimals) {
    final base = BigInt.from(10).pow(decimals);
    final whole = value ~/ base;
    final fraction = value.remainder(base).toString().padLeft(decimals, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    if (trimmed.isEmpty) {
      return whole.toString();
    }
    return '$whole.$trimmed';
  }
}

/// Solana SPL Token 的原始余额汇总结果。
class _SolanaTokenBalance {
  const _SolanaTokenBalance({required this.rawAmount, required this.decimals});

  /// token 最小单位数量。
  final BigInt rawAmount;

  /// token 精度，优先使用链上 token account 返回值。
  final int decimals;
}
