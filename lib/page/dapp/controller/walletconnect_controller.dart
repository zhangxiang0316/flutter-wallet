import 'package:get/get.dart';
import 'package:reown_walletkit/reown_walletkit.dart';

import '../../../base/base_controller.dart';
import '../../../wallet/models/wallet.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/walletconnect_service.dart';
import '../services/dapp_request_router.dart';
import '../view/connection_request_sheet.dart';

/// WalletConnect 控制器
///
/// 负责：
/// - 监听 WalletConnect 事件
/// - 显示连接请求确认界面
/// - 协调请求处理
class WalletConnectController extends BaseController {
  final WalletConnectService _wcService = WalletConnectService.instance;
  final WalletRepository _repository = WalletRepository();
  final DAppRequestRouter _requestRouter = DAppRequestRouter();

  @override
  void onInit() {
    super.onInit();
    _initializeWalletConnect();
  }

  /// 初始化 WalletConnect 并监听事件
  Future<void> _initializeWalletConnect() async {
    try {
      await _wcService.initialize();
      _listenToEvents();
    } catch (e) {
      debugPrint('❌ WalletConnect initialization failed: $e');
    }
  }

  /// 监听 WalletConnect 事件
  void _listenToEvents() {
    // 监听会话提案（DApp 请求连接）
    _wcService.onSessionProposal.listen((event) {
      _handleConnectionRequest(event);
    });

    // 监听会话请求（交易、签名等）
    _wcService.onSessionRequest.listen((event) {
      _handleSessionRequest(event);
    });

    // 监听会话删除
    _wcService.onSessionDelete.listen((event) {
      debugPrint('📨 Session deleted: ${event.topic}');
    });
  }

  /// 处理连接请求
  Future<void> _handleConnectionRequest(SessionProposalEvent event) async {
    try {
      // 获取当前钱包
      final wallet = await _getCurrentWallet();
      if (wallet == null) {
        await _wcService.rejectSession(
          proposalId: event.id,
          reason: 'No wallet available',
        );
        return;
      }

      // 获取当前钱包地址（使用第一个链的地址）
      final address = wallet.ethereumAddress ?? '';
      if (address.isEmpty) {
        await _wcService.rejectSession(
          proposalId: event.id,
          reason: 'No address available',
        );
        return;
      }

      // 显示连接确认界面
      final approved = await ConnectionRequestSheet.show(
        context: Get.context!,
        proposal: event.params,
        walletAddress: address,
      );

      if (approved == true) {
        // 用户批准连接
        final requiredNamespace = event.params.requiredNamespaces['eip155'];
        final chains = requiredNamespace?.chains ?? ['eip155:1'];

        await _wcService.approveSession(
          proposalId: event.id,
          address: address,
          chains: chains,
        );

        debugPrint('✅ Session approved with ${chains.length} chains');
      } else {
        // 用户拒绝连接
        await _wcService.rejectSession(
          proposalId: event.id,
          reason: 'User rejected',
        );
        debugPrint('❌ Session rejected by user');
      }
    } catch (e) {
      debugPrint('❌ Handle connection request failed: $e');
      await _wcService.rejectSession(
        proposalId: event.id,
        reason: 'Error: $e',
      );
    }
  }

  /// 处理会话请求（交易、签名等）
  Future<void> _handleSessionRequest(SessionRequestEvent event) async {
    try {
      // 使用请求路由器处理
      await _requestRouter.handleRequest(event);
    } catch (e) {
      debugPrint('❌ Handle session request failed: $e');
      // 发送错误响应
      await _wcService.respondError(
        topic: event.topic,
        requestId: event.id,
        error: e.toString(),
      );
    }
  }

  /// 获取当前钱包
  Future<Wallet?> _getCurrentWallet() async {
    try {
      final wallets = await _repository.listWallets();
      return wallets.isNotEmpty ? wallets.first : null;
    } catch (e) {
      debugPrint('❌ Get current wallet failed: $e');
      return null;
    }
  }

  /// 获取所有活动会话
  List<SessionData> getActiveSessions() {
    return _wcService.getActiveSessions();
  }

  /// 断开指定会话
  Future<void> disconnectSession(String topic) async {
    await _wcService.disconnectSession(topic);
  }

  @override
  void onClose() {
    // 清理资源
    super.onClose();
  }
}
