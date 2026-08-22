import 'package:dio/dio.dart';
import 'package:sui/sui.dart';

import '../../adapters/chain_adapter.dart';
import '../../adapters/chain_adapter_registry.dart';
import '../../adapters/default_chain_adapter_registry.dart';
import '../../models/wallet_chain.dart';
import '../../models/wallet_transaction_record.dart';

/// 单笔交易状态查询服务。
///
/// 该服务只按交易 hash 查询当前确认状态，用于本地提交记录从 pending 过渡到
/// success/failed。完整交易列表仍由 [WalletTransactionHistoryService] 负责。
class WalletTransactionStatusService {
  WalletTransactionStatusService({
    Dio? dio,
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
       _adapterRegistry =
           adapterRegistry ?? createDefaultChainAdapterRegistry();

  final Dio _dio;
  final ChainAdapterRegistry _adapterRegistry;

  static const Duration _requestTimeout = Duration(seconds: 6);

  Future<WalletTransactionStatus> loadStatus({
    required WalletChainRef chain,
    required String txHash,
  }) async {
    final hash = txHash.trim();
    if (hash.isEmpty) return WalletTransactionStatus.unknown;
    final adapter = _adapterRegistry.require(
      chain,
      capability: ChainCapability.transactionStatus,
    );
    final handlers =
        <WalletChainType, Future<WalletTransactionStatus> Function()>{
          WalletChainType.evm: () => _loadEvmStatus(chain, hash),
          WalletChainType.solana: () => _loadSolanaStatus(chain, hash),
          WalletChainType.tron: () => _loadTronStatus(chain, hash),
          WalletChainType.bitcoin: () => _loadBitcoinStatus(chain, hash),
          WalletChainType.sui: () => _loadSuiStatus(chain, hash),
          WalletChainType.aptos: () => _loadAptosStatus(chain, hash),
        };
    return handlers[adapter.type]?.call() ?? WalletTransactionStatus.unknown;
  }

  Future<WalletTransactionStatus> _loadEvmStatus(
    WalletChainRef chain,
    String txHash,
  ) async {
    final data = await _postRpc(chain.rpcUrl, {
      'jsonrpc': '2.0',
      'method': 'eth_getTransactionReceipt',
      'params': [txHash],
      'id': 1,
    });
    final receipt = data['result'];
    if (receipt == null) return WalletTransactionStatus.pending;
    if (receipt is! Map) return WalletTransactionStatus.unknown;
    return receipt['status']?.toString() == '0x0'
        ? WalletTransactionStatus.failed
        : WalletTransactionStatus.success;
  }

  Future<WalletTransactionStatus> _loadSolanaStatus(
    WalletChainRef chain,
    String txHash,
  ) async {
    final data = await _postRpc(chain.rpcUrl, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'getSignatureStatuses',
      'params': [
        [txHash],
        {'searchTransactionHistory': true},
      ],
    });
    final result = data['result'];
    final values = result is Map ? result['value'] : null;
    final status = values is List && values.isNotEmpty ? values.first : null;
    if (status == null) return WalletTransactionStatus.pending;
    if (status is! Map) return WalletTransactionStatus.unknown;
    return status['err'] == null
        ? WalletTransactionStatus.success
        : WalletTransactionStatus.failed;
  }

  Future<WalletTransactionStatus> _loadTronStatus(
    WalletChainRef chain,
    String txHash,
  ) async {
    final response = await _dio.post(
      '${chain.rpcUrl}/wallet/gettransactioninfobyid',
      data: {'value': txHash},
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is! Map || data.isEmpty) {
      return WalletTransactionStatus.pending;
    }
    final receipt = data['receipt'];
    final result = receipt is Map ? receipt['result']?.toString() : null;
    if (result == 'SUCCESS') return WalletTransactionStatus.success;
    if (result != null && result.isNotEmpty) {
      return WalletTransactionStatus.failed;
    }
    final ret = data['ret'];
    if (ret is List && ret.isNotEmpty) {
      final first = ret.first;
      final contractRet = first is Map
          ? first['contractRet']?.toString()
          : null;
      if (contractRet == 'SUCCESS') return WalletTransactionStatus.success;
      if (contractRet != null && contractRet.isNotEmpty) {
        return WalletTransactionStatus.failed;
      }
    }
    return WalletTransactionStatus.pending;
  }

  Future<WalletTransactionStatus> _loadBitcoinStatus(
    WalletChainRef chain,
    String txHash,
  ) async {
    final response = await _dio.get('${chain.rpcUrl}/tx/$txHash/status');
    final data = response.data;
    if (data is! Map) return WalletTransactionStatus.unknown;
    return data['confirmed'] == true
        ? WalletTransactionStatus.success
        : WalletTransactionStatus.pending;
  }

  Future<WalletTransactionStatus> _loadSuiStatus(
    WalletChainRef chain,
    String txHash,
  ) async {
    try {
      final transaction = await SuiGrpcClient(
        network: SuiNetwork.mainnet,
        dio: _dio,
        endpoint: chain.rpcUrl,
      ).getTransaction(txHash);
      return transaction.effects.status.success
          ? WalletTransactionStatus.success
          : WalletTransactionStatus.failed;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return WalletTransactionStatus.pending;
      }
      rethrow;
    }
  }

  Future<WalletTransactionStatus> _loadAptosStatus(
    WalletChainRef chain,
    String txHash,
  ) async {
    try {
      final response = await _dio.get(
        '${chain.rpcUrl}/transactions/by_hash/$txHash',
      );
      final data = response.data;
      if (data is! Map) return WalletTransactionStatus.unknown;
      if (data['type'] == 'pending_transaction') {
        return WalletTransactionStatus.pending;
      }
      return data['success'] == true
          ? WalletTransactionStatus.success
          : WalletTransactionStatus.failed;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return WalletTransactionStatus.pending;
      }
      rethrow;
    }
  }

  Future<Map<dynamic, dynamic>> _postRpc(
    String rpcUrl,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post(
      rpcUrl,
      data: body,
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is Map) return data;
    throw StateError('Invalid RPC response');
  }
}
