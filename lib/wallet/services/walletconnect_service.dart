import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:reown_walletkit/reown_walletkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WalletConnect 会话管理服务
///
/// 负责：
/// - 初始化 WalletConnect SDK
/// - 处理配对（扫码连接）
/// - 管理活动会话
/// - 监听和分发事件（连接请求、交易请求等）
class WalletConnectService {
  WalletConnectService._();

  static final WalletConnectService instance = WalletConnectService._();

  /// WalletConnect SDK 实例
  ReownWalletKit? _walletKit;

  /// 是否已初始化
  bool _initialized = false;

  /// 会话提案事件流控制器
  final _sessionProposalController = StreamController<SessionProposalEvent>.broadcast();

  /// 会话请求事件流控制器
  final _sessionRequestController = StreamController<SessionRequestEvent>.broadcast();

  /// 会话删除事件流控制器
  final _sessionDeleteController = StreamController<SessionDeleteEvent>.broadcast();

  /// 会话提案事件流
  Stream<SessionProposalEvent> get onSessionProposal => _sessionProposalController.stream;

  /// 会话请求事件流（交易、签名等）
  Stream<SessionRequestEvent> get onSessionRequest => _sessionRequestController.stream;

  /// 会话删除事件流
  Stream<SessionDeleteEvent> get onSessionDelete => _sessionDeleteController.stream;

  /// 初始化 WalletConnect
  ///
  /// 需要在应用启动时调用一次
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 创建 WalletKit 实例
      _walletKit = await ReownWalletKit.createInstance(
        projectId: _getProjectId(),
        logLevel: kDebugMode ? LogLevel.debug : LogLevel.error,
        metadata: const PairingMetadata(
          name: 'Omnicast Wallet',
          description: 'Multi-chain crypto wallet',
          url: 'https://github.com/your-repo/omnicast',
          icons: ['https://your-domain.com/logo.png'],
          redirect: Redirect(
            native: 'omnicast://',
            universal: 'https://your-domain.com',
          ),
        ),
      );

      // 注册事件监听器
      _registerEventHandlers();

      // 恢复持久化的会话
      await _restoreSessions();

      _initialized = true;
      debugPrint('✅ WalletConnect initialized successfully');
    } catch (e) {
      debugPrint('❌ WalletConnect initialization failed: $e');
      rethrow;
    }
  }

  /// 通过 URI 配对（扫码后调用）
  ///
  /// [uri] 格式: wc:xxx@2?relay-protocol=irn&symKey=xxx
  Future<void> pair(String uri) async {
    if (_walletKit == null) {
      throw Exception('WalletConnect not initialized');
    }

    try {
      final parsedUri = ReownCoreUtils.parseUri(Uri.parse(uri));
      await _walletKit!.pair(uri: parsedUri);
      debugPrint('✅ Pairing initiated with URI: ${uri.substring(0, 20)}...');
    } catch (e) {
      debugPrint('❌ Pairing failed: $e');
      rethrow;
    }
  }

  /// 批准会话提案
  ///
  /// 用户确认连接后调用
  Future<void> approveSession({
    required int proposalId,
    required String address,
    required List<String> chains,
  }) async {
    if (_walletKit == null) {
      throw Exception('WalletConnect not initialized');
    }

    try {
      // 构建支持的链账户
      final accounts = chains.map((chain) => '$chain:$address').toList();

      // 批准会话
      await _walletKit!.approveSession(
        id: proposalId,
        namespaces: {
          'eip155': SessionNamespace(
            chains: chains,
            methods: [
              'eth_sendTransaction',
              'eth_signTransaction',
              'personal_sign',
              'eth_sign',
              'eth_signTypedData',
              'eth_signTypedData_v4',
            ],
            events: [
              'chainChanged',
              'accountsChanged',
            ],
            accounts: accounts,
          ),
        },
      );

      // 持久化会话
      await _saveSessions();

      debugPrint('✅ Session approved for chains: $chains');
    } catch (e) {
      debugPrint('❌ Approve session failed: $e');
      rethrow;
    }
  }

  /// 拒绝会话提案
  Future<void> rejectSession({
    required int proposalId,
    String reason = 'User rejected',
  }) async {
    if (_walletKit == null) {
      throw Exception('WalletConnect not initialized');
    }

    try {
      await _walletKit!.rejectSession(
        id: proposalId,
        reason: ReownSignError(
          code: 5000,
          message: reason,
        ),
      );
      debugPrint('✅ Session rejected: $reason');
    } catch (e) {
      debugPrint('❌ Reject session failed: $e');
      rethrow;
    }
  }

  /// 响应会话请求（交易、签名等）
  ///
  /// [topic] 会话主题
  /// [requestId] 请求 ID
  /// [result] 响应结果（交易哈希、签名等）
  Future<void> respondRequest({
    required String topic,
    required int requestId,
    required dynamic result,
  }) async {
    if (_walletKit == null) {
      throw Exception('WalletConnect not initialized');
    }

    try {
      await _walletKit!.respondSessionRequest(
        topic: topic,
        response: JsonRpcResponse(
          id: requestId,
          result: result,
        ),
      );
      debugPrint('✅ Request responded: $requestId');
    } catch (e) {
      debugPrint('❌ Respond request failed: $e');
      rethrow;
    }
  }

  /// 响应请求错误
  Future<void> respondError({
    required String topic,
    required int requestId,
    required String error,
  }) async {
    if (_walletKit == null) {
      throw Exception('WalletConnect not initialized');
    }

    try {
      await _walletKit!.respondSessionRequest(
        topic: topic,
        response: JsonRpcResponse(
          id: requestId,
          error: JsonRpcError(
            code: 5000,
            message: error,
          ),
        ),
      );
      debugPrint('✅ Request error responded: $error');
    } catch (e) {
      debugPrint('❌ Respond error failed: $e');
      rethrow;
    }
  }

  /// 获取所有活动会话
  List<SessionData> getActiveSessions() {
    if (_walletKit == null) return [];
    return _walletKit!.getActiveSessions().values.toList();
  }

  /// 断开指定会话
  Future<void> disconnectSession(String topic) async {
    if (_walletKit == null) {
      throw Exception('WalletConnect not initialized');
    }

    try {
      await _walletKit!.disconnectSession(
        topic: topic,
        reason: ReownSignError(
          code: 6000,
          message: 'User disconnected',
        ),
      );

      // 更新持久化
      await _saveSessions();

      debugPrint('✅ Session disconnected: $topic');
    } catch (e) {
      debugPrint('❌ Disconnect session failed: $e');
      rethrow;
    }
  }

  /// 断开所有会话
  Future<void> disconnectAllSessions() async {
    final sessions = getActiveSessions();
    for (final session in sessions) {
      await disconnectSession(session.topic);
    }
  }

  /// 注册事件处理器
  void _registerEventHandlers() {
    if (_walletKit == null) return;

    // 监听会话提案（DApp 请求连接）
    _walletKit!.onSessionProposal.subscribe((event) {
      debugPrint('📨 Session proposal received from: ${event?.params.proposer.metadata.name}');
      if (event != null) {
        _sessionProposalController.add(event);
      }
    });

    // 监听会话请求（交易、签名等）
    _walletKit!.onSessionRequest.subscribe((event) {
      debugPrint('📨 Session request received: ${event?.params.request.method}');
      if (event != null) {
        _sessionRequestController.add(event);
      }
    });

    // 监听会话删除
    _walletKit!.onSessionDelete.subscribe((event) {
      debugPrint('📨 Session deleted: ${event?.topic}');
      if (event != null) {
        _sessionDeleteController.add(event);
      }
    });
  }

  /// 保存会话到本地存储
  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = getActiveSessions();
      final sessionTopics = sessions.map((s) => s.topic).toList();
      await prefs.setStringList('wc_session_topics', sessionTopics);
      debugPrint('💾 Saved ${sessions.length} sessions');
    } catch (e) {
      debugPrint('⚠️ Save sessions failed: $e');
    }
  }

  /// 从本地存储恢复会话
  Future<void> _restoreSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final topics = prefs.getStringList('wc_session_topics') ?? [];
      debugPrint('📂 Restored ${topics.length} session topics');
    } catch (e) {
      debugPrint('⚠️ Restore sessions failed: $e');
    }
  }

  /// 获取 WalletConnect Project ID
  ///
  /// 从 WalletConnect Cloud 获取: https://cloud.walletconnect.com/
  String _getProjectId() {
    // TODO: 替换为你的 Project ID
    // 访问 https://cloud.walletconnect.com/ 创建项目并获取 ID
    const projectId = 'YOUR_PROJECT_ID_HERE';

    if (projectId == 'YOUR_PROJECT_ID_HERE') {
      debugPrint('⚠️ WARNING: Using placeholder Project ID');
      debugPrint('⚠️ Get your Project ID from: https://cloud.walletconnect.com/');
    }

    return projectId;
  }

  /// 清理资源
  void dispose() {
    _sessionProposalController.close();
    _sessionRequestController.close();
    _sessionDeleteController.close();
  }
}
