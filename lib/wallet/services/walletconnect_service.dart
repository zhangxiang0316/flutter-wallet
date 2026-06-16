import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:reown_walletkit/reown_walletkit.dart';

/// WalletConnect 服务 (完整实现)
///
/// 使用 reown_walletkit SDK 实现真实的 WalletConnect v2 协议
class WalletConnectService {
  WalletConnectService._();
  static final WalletConnectService instance = WalletConnectService._();

  ReownWalletKit? _walletKit;
  bool _initialized = false;

  /// 获取 WalletKit 实例
  ReownWalletKit get walletKit {
    if (_walletKit == null) {
      throw Exception('WalletConnect not initialized');
    }
    return _walletKit!;
  }

  /// 会话提案事件 (直接返回 Event 对象，由 Controller 订阅)
  Event<SessionProposalEvent>? get onSessionProposal => _walletKit?.onSessionProposal;

  /// 会话请求事件
  Event<SessionRequestEvent>? get onSessionRequest => _walletKit?.onSessionRequest;

  /// 会话删除事件
  Event<SessionDelete>? get onSessionDelete => _walletKit?.onSessionDelete;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('🚀 Initializing WalletConnect...');

      // TODO: 从配置或环境变量读取
      const projectId = 'YOUR_PROJECT_ID_HERE';

      if (projectId == 'YOUR_PROJECT_ID_HERE') {
        debugPrint('⚠️ WARNING: Using placeholder project ID');
        debugPrint('⚠️ Get your project ID from: https://cloud.walletconnect.com/');
      }

      _walletKit = ReownWalletKit(
        core: ReownCore(
          projectId: projectId,
        ),
        metadata: const PairingMetadata(
          name: 'Omnicast Wallet',
          description: 'Multi-chain crypto wallet',
          url: 'https://github.com/your-org/omnicast',
          icons: ['https://your-domain.com/icon.png'],
        ),
      );

      await _walletKit!.init();
      _initialized = true;

      debugPrint('✅ WalletConnect initialized successfully');
      debugPrint('   Protocol: ${_walletKit!.protocol}');
      debugPrint('   Version: ${_walletKit!.version}');
    } catch (e, stack) {
      debugPrint('❌ WalletConnect initialization failed: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// 通过 URI 配对
  Future<PairingInfo> pair(String uriString) async {
    if (!_initialized || _walletKit == null) {
      throw Exception('WalletConnect not initialized');
    }

    try {
      debugPrint('📨 Pairing with URI: ${uriString.substring(0, 30)}...');

      final uri = Uri.parse(uriString);
      final pairingInfo = await _walletKit!.pair(uri: uri);

      debugPrint('✅ Pairing initiated');
      debugPrint('   Topic: ${pairingInfo.topic}');

      return pairingInfo;
    } catch (e, stack) {
      debugPrint('❌ Pairing failed: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// 批准会话
  Future<void> approveSession({
    required int proposalId,
    required String address,
    List<String>? chains,
  }) async {
    try {
      debugPrint('✅ Approving session: $proposalId');
      debugPrint('   Address: $address');

      // 构造 Namespace
      final namespaces = <String, Namespace>{};

      // EVM chains
      final evmChains = chains ?? ['eip155:1']; // 默认以太坊主网
      namespaces['eip155'] = Namespace(
        accounts: evmChains.map((chain) => '$chain:$address').toList(),
        methods: [
          'eth_sendTransaction',
          'eth_signTransaction',
          'eth_sign',
          'personal_sign',
          'eth_signTypedData',
          'eth_signTypedData_v4',
        ],
        events: ['chainChanged', 'accountsChanged'],
      );

      await _walletKit!.approveSession(
        id: proposalId,
        namespaces: namespaces,
      );

      debugPrint('✅ Session approved successfully');
    } catch (e, stack) {
      debugPrint('❌ Approve session failed: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// 拒绝会话
  Future<void> rejectSession({
    required int proposalId,
    String reason = 'User rejected',
  }) async {
    try {
      debugPrint('❌ Rejecting session: $proposalId');
      debugPrint('   Reason: $reason');

      await _walletKit!.rejectSession(
        id: proposalId,
        reason: ReownSignError(
          code: 5000,
          message: reason,
        ),
      );

      debugPrint('✅ Session rejected');
    } catch (e, stack) {
      debugPrint('❌ Reject session failed: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// 响应会话请求（成功）
  Future<void> respondSuccess({
    required String topic,
    required int requestId,
    required String result,
  }) async {
    try {
      debugPrint('✅ Responding to request: $requestId');

      await _walletKit!.respondSessionRequest(
        topic: topic,
        response: JsonRpcResponse(
          id: requestId,
          jsonrpc: '2.0',
          result: result,
        ),
      );

      debugPrint('✅ Response sent successfully');
    } catch (e, stack) {
      debugPrint('❌ Respond success failed: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// 响应会话请求（错误）
  Future<void> respondError({
    required String topic,
    required int requestId,
    required String error,
  }) async {
    try {
      debugPrint('❌ Responding error to request: $requestId');

      await _walletKit!.respondSessionRequest(
        topic: topic,
        response: JsonRpcResponse(
          id: requestId,
          jsonrpc: '2.0',
          error: JsonRpcError(code: 5000, message: error),
        ),
      );

      debugPrint('✅ Error response sent');
    } catch (e, stack) {
      debugPrint('❌ Respond error failed: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// 获取所有活动会话
  List<SessionData> getActiveSessions() {
    if (_walletKit == null) return [];
    return _walletKit!.sessions.getAll();
  }

  /// 断开会话
  Future<void> disconnectSession(String topic) async {
    try {
      debugPrint('🔌 Disconnecting session: $topic');

      await _walletKit!.disconnectSession(
        topic: topic,
        reason: ReownSignError(
          code: 6000,
          message: 'User disconnected',
        ),
      );

      debugPrint('✅ Session disconnected');
    } catch (e, stack) {
      debugPrint('❌ Disconnect failed: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// 清理资源
  void dispose() {
    // SDK 会自动清理
  }
}
