import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:solana/solana.dart';
import 'package:sui/sui.dart';

import '../adapters/chain_adapter.dart';
import '../adapters/chain_adapter_registry.dart';
import '../adapters/default_chain_adapter_registry.dart';
import '../models/chain_balance.dart';
import '../models/wallet_asset.dart';
import '../models/wallet_chain.dart';
import '../utils/rpc_retry_helper.dart';
import 'config/wallet_chain_config_service.dart';
import 'config/wallet_custom_asset_service.dart';
import 'wallet_history_api_config.dart';
import 'wallet_transfer_service.dart';

part 'balance/chain_balance_routes.dart';
part 'balance/evm_chain_balance.dart';
part 'balance/tron_chain_balance.dart';
part 'balance/solana_chain_balance.dart';
part 'balance/bitcoin_chain_balance.dart';
part 'balance/sui_chain_balance.dart';
part 'balance/aptos_chain_balance.dart';

/// 单条链余额完成后的增量回调。
typedef ChainBalancesCallback = void Function(List<ChainBalance> balances);

/// 多链余额查询服务。
///
/// 首页资产列表依赖该服务一次性查询所有支持链的余额。当前支持：
/// - BNB Smart Chain / Ethereum / X Layer / Arbitrum / Base / Polygon / Avalanche：通过 EVM JSON-RPC 查询原生币和 ERC20；
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
  ChainBalanceService({
    Dio? dio,
    WalletCustomAssetService? customAssetService,
    WalletChainConfigService? chainConfigService,
    WalletHistoryApiConfig? apiConfig,
    ChainAdapterRegistry? adapterRegistry,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: _requestTimeout,
               receiveTimeout: _requestTimeout,
               sendTimeout: _requestTimeout,
             ),
           ),
       _customAssetService = customAssetService ?? WalletCustomAssetService(),
       _chainConfigService = chainConfigService ?? WalletChainConfigService(),
       _apiConfig = apiConfig ?? const WalletHistoryApiConfig(),
       _adapterRegistry =
           adapterRegistry ?? createDefaultChainAdapterRegistry();

  /// RPC/HTTP 请求客户端。
  final Dio _dio;

  /// 用户自定义资产服务，用于把用户添加的代币合并进默认查询列表。
  final WalletCustomAssetService _customAssetService;

  /// 动态链配置服务，用于把用户添加的 EVM 网络纳入余额查询。
  final WalletChainConfigService _chainConfigService;

  /// 第三方 API 配置。余额服务目前复用 Helius RPC 和 TronGrid Key。
  final WalletHistoryApiConfig _apiConfig;

  final ChainAdapterRegistry _adapterRegistry;

  /// 常规链 RPC 请求超时时间。
  static const Duration _requestTimeout = Duration(seconds: 12);

  /// Solana 单次 RPC 请求超时时间。
  ///
  /// Solana 公共节点偶尔响应较慢，单次请求设置得更短，避免拖慢整个首页刷新。
  static const Duration _solanaRequestTimeout = Duration(seconds: 3);

  /// 单条链余额查询的总超时时间，避免任意慢节点拖住整次首页刷新。
  static const Duration _chainBalanceTimeout = Duration(seconds: 6);

  /// EVM 单个 RPC 节点的尝试时间，超时后尽快切换备用节点。
  static const Duration _evmRequestTimeout = Duration(seconds: 3);

  /// EVM 链 RPC 备用节点。
  ///
  /// 每条 EVM 链按顺序尝试节点，前一个失败后自动切到下一个。
  /// 优先使用快速稳定的免费节点（Ankr、bloXroute）。
  static const Map<WalletChain, List<String>> _evmRpcFallbacks = {
    WalletChain.bsc: [
      'https://bsc.rpc.blxrbdn.com', // bloXroute - 快速
      'https://rpc.ankr.com/bsc', // Ankr - 稳定
      'https://bsc-dataseed.bnbchain.org',
      'https://bsc-rpc.publicnode.com',
    ],
    WalletChain.ethereum: [
      'https://eth.rpc.blxrbdn.com', // bloXroute - 快速
      'https://rpc.ankr.com/eth', // Ankr - 稳定
      'https://ethereum-rpc.publicnode.com',
      'https://eth.llamarpc.com',
    ],
    WalletChain.xLayer: [
      'https://rpc.xlayer.tech',
      'https://xlayerrpc.okx.com',
    ],
    WalletChain.arbitrum: [
      'https://arbitrum-one-rpc.publicnode.com',
      'https://arbitrum.llamarpc.com',
      'https://rpc.ankr.com/arbitrum',
      'https://arb1.arbitrum.io/rpc',
    ],
    WalletChain.base: [
      'https://base-rpc.publicnode.com',
      'https://rpc.ankr.com/base',
      'https://base.llamarpc.com',
      'https://mainnet.base.org',
    ],
    WalletChain.polygon: [
      'https://polygon.drpc.org',
      'https://polygon.publicnode.com',
      'https://tenderly.rpc.polygon.community',
      'https://1rpc.io/matic',
    ],
    WalletChain.avalanche: [
      'https://api.avax.network/ext/bc/C/rpc',
      'https://avalanche-c-chain-rpc.publicnode.com',
      'https://avalanche.drpc.org',
      'https://1rpc.io/avax/c',
    ],
  };

  /// TRON 账号查询备用节点。
  static const List<String> _tronRpcFallbacks = [
    'https://api.trongrid.io',
    'https://tron-rpc.publicnode.com',
  ];

  /// Solana JSON-RPC 备用节点。
  ///
  /// 优先使用快速稳定的节点，官方节点作为备用。
  static const List<String> _solanaRpcFallbacks = [
    'https://solana-mainnet.rpc.extrnode.com',
    'https://rpc.ankr.com/solana',
    'https://solana-rpc.publicnode.com',
    'https://api.mainnet-beta.solana.com',
  ];

  /// Bitcoin Mainnet Esplora 兼容 API 备用节点。
  static const List<String> _bitcoinApiFallbacks = [
    'https://mempool.space/api',
    'https://blockstream.info/api',
  ];

  /// Solana SPL Token Program 地址。
  ///
  /// USDT、USDC 等主流稳定币都使用该 program。按 mint 查询失败时，会用该
  /// program 兜底拉取 owner 下的 token account。
  static const String _solanaTokenProgramId =
      'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';

  /// 查询当前钱包在所有支持链上的资产余额。
  ///
  /// [bscAddress] 实际代表 EVM 地址，BSC、Ethereum、X Layer、Arbitrum、Base、Polygon、Avalanche 共用它；
  /// [tronAddress] 和 [solanaAddress] 分别用于 TRON 和 Solana。
  /// 各链并发查询，最终把多链结果拍平成一个 [ChainBalance] 列表。
  Future<List<ChainBalance>> loadBalances({
    required String bscAddress,
    required String tronAddress,
    required String solanaAddress,
    String suiAddress = '',
    String aptosAddress = '',
    String bitcoinAddress = '',
    ChainBalancesCallback? onChainBalances,
  }) async {
    final customAssets = await _customAssetService.loadCustomAssets();
    final enabledChains = await _chainConfigService.loadEnabledChains();
    final addresses = ChainWalletAddresses(
      evm: bscAddress,
      tron: tronAddress,
      solana: solanaAddress,
      bitcoin: bitcoinAddress,
      sui: suiAddress,
      aptos: aptosAddress,
    );
    final tasks = <Future<List<ChainBalance>>>[];

    for (final chain in enabledChains) {
      final adapter = _adapterRegistry.require(
        chain,
        capability: ChainCapability.balance,
      );
      final address = adapter.walletAddress(addresses);
      if (address.isEmpty) continue;
      final assets = WalletAssetRegistry.mergeCustomAssetsForChainConfig(
        chain,
        customAssets,
      );
      final operations =
          <WalletChainType, Future<List<ChainBalance>> Function()>{
            WalletChainType.evm: () => _loadEvmBalances(
              chain: chain,
              assets: assets,
              address: address,
            ),
            WalletChainType.solana: () => _loadSolanaBalances(
              chain: chain,
              address: address,
              customAssets: customAssets,
            ),
            WalletChainType.tron: () => _loadTronBalances(
              chain: chain,
              address: address,
              customAssets: customAssets,
            ),
            WalletChainType.bitcoin: () =>
                _loadBitcoinBalances(chain: chain, address: address),
            WalletChainType.sui: () =>
                _loadSuiBalances(chain: chain, address: address),
            WalletChainType.aptos: () =>
                _loadAptosBalances(chain: chain, address: address),
          };
      final operation = operations[adapter.type];
      if (operation == null) {
        throw StateError('Missing balance handler for ${adapter.type.name}');
      }
      final fallback = adapter.type == WalletChainType.solana
          ? (String error) => _fallbackSolanaBalances(
              chain: chain,
              address: address,
              customAssets: customAssets,
              error: error,
            )
          : (String error) => _fallbackBalancesForAssets(
              chain: chain,
              assets: assets,
              address: address,
              error: error,
            );
      tasks.add(
        _runChainBalanceLoad(
          chainName: chain.name,
          operation: operation(),
          fallback: fallback,
          onChainBalances: onChainBalances,
        ),
      );
    }

    final results = await Future.wait(tasks);
    final balances = results.expand((items) => items).toList();
    _printLoadedBalances(results, balances);
    return balances;
  }

  /// 仅刷新一条链的余额。
  ///
  /// 转账确认后使用该入口获取最新资产余额和原生币余额，避免为了签名前校验
  /// 重复请求钱包中的所有网络。查询失败时返回带 [ChainBalance.error] 的兜底
  /// 余额，由调用方停止签名。
  Future<List<ChainBalance>> loadChainBalances({
    required WalletChainConfig chain,
    required String address,
  }) async {
    final customAssets = await _customAssetService.loadCustomAssets();
    final assets = WalletAssetRegistry.mergeCustomAssetsForChainConfig(
      chain,
      customAssets,
    );
    final adapter = _adapterRegistry.require(
      chain,
      capability: ChainCapability.balance,
    );
    final operations = <WalletChainType, Future<List<ChainBalance>> Function()>{
      WalletChainType.evm: () =>
          _loadEvmBalances(chain: chain, assets: assets, address: address),
      WalletChainType.solana: () => _loadSolanaBalances(
        chain: chain,
        address: address,
        customAssets: customAssets,
      ),
      WalletChainType.tron: () => _loadTronBalances(
        chain: chain,
        address: address,
        customAssets: customAssets,
      ),
      WalletChainType.bitcoin: () =>
          _loadBitcoinBalances(chain: chain, address: address),
      WalletChainType.sui: () =>
          _loadSuiBalances(chain: chain, address: address),
      WalletChainType.aptos: () =>
          _loadAptosBalances(chain: chain, address: address),
    };
    final operation = operations[adapter.type];
    if (operation == null) {
      throw StateError('Missing balance handler for ${adapter.type.name}');
    }
    final fallback = adapter.type == WalletChainType.solana
        ? (String error) => _fallbackSolanaBalances(
            chain: chain,
            address: address,
            customAssets: customAssets,
            error: error,
          )
        : (String error) => _fallbackBalancesForAssets(
            chain: chain,
            assets: assets,
            address: address,
            error: error,
          );

    return _runChainBalanceLoad(
      chainName: chain.name,
      operation: operation(),
      fallback: fallback,
    );
  }

  /// 限制单条链的总等待时间，并在完成时立即通知首页。
  Future<List<ChainBalance>> _runChainBalanceLoad({
    required String chainName,
    required Future<List<ChainBalance>> operation,
    required List<ChainBalance> Function(String error) fallback,
    ChainBalancesCallback? onChainBalances,
  }) async {
    late final List<ChainBalance> result;
    try {
      result = await operation.timeout(_chainBalanceTimeout);
    } on TimeoutException {
      final error = '$chainName balance lookup timed out';
      developer.log(
        '$error; using zero fallback balances',
        name: 'ChainBalanceService',
      );
      result = fallback(error);
    } catch (error) {
      developer.log(
        '$chainName balance lookup failed; using zero fallback balances',
        error: error,
        name: 'ChainBalanceService',
      );
      result = fallback(error.toString());
    }
    onChainBalances?.call(result);
    return result;
  }

  /// 向 EVM 链发送 JSON-RPC 请求。
  ///
  /// 该方法统一处理多 RPC fallback、错误响应识别和日志记录。只有响应中存在
  ///字符串类型的 `result` 时才视为成功。
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
