import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:reown_walletkit/reown_walletkit.dart';

import '../../../base/base_controller.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/walletconnect_service.dart';
import '../view/connection_request_sheet.dart';

/// WalletConnect 控制器 (真实 SDK 集成)
class WalletConnectController extends BaseController {
  final WalletConnectService _wcService = WalletConnectService.instance;
  final WalletRepository _repository = WalletRepository();

  StreamSubscription<SessionProposalEvent>? _proposalSubscription;
  StreamSubscription<SessionRequestEvent>? _requestSubscription;

  @override
  void onInit() {
    super.onInit();
    _initializeWalletConnect();
  }

  Future<void> _initializeWalletConnect() async {
    try {
      await _wcService.initialize();
      _listenToEvents();
    } catch (e) {
      debugPrint('❌ WalletConnect initialization failed: $e');
      Toast.show('WalletConnect init failed. Check Project ID.');
    }
  }

  void _listenToEvents() {
    // 取消之前的订阅
    _proposalSubscription?.cancel();
    _requestSubscription?.cancel();

    // 监听会话提案（DApp 请求连接）
    _proposalSubscription = _wcService.onSessionProposal.listen((event) {
      debugPrint('📥 Session proposal received');
      _handleConnectionRequest(event);
    });

    // 监听会话请求（交易、签名等）
    _requestSubscription = _wcService.onSessionRequest.listen((event) {
      debugPrint('📥 Session request received: ${event.method}');
      _handleSessionRequest(event);
    });
  }

  Future<void> _handleConnectionRequest(SessionProposalEvent event) async {
    try {
      debugPrint('📥 Handling connection request');
      debugPrint('   Proposer: ${event.params.proposer.metadata.name}');
      debugPrint('   URL: ${event.params.proposer.metadata.url}');

      final wallet = await _repository.loadCurrentWallet();
      if (wallet == null) {
        debugPrint('❌ No wallet available');
        await _wcService.rejectSession(
          proposalId: event.id,
          reason: 'No wallet',
        );
        Toast.show('Please create a wallet first');
        return;
      }

      final address = wallet.bscAddress;
      if (address.isEmpty) {
        debugPrint('❌ No wallet address');
        await _wcService.rejectSession(
          proposalId: event.id,
          reason: 'No address',
        );
        Toast.show('No wallet address');
        return;
      }

      debugPrint('💬 Showing connection request dialog...');
      debugPrint('   Address: $address');

      // 转换为我们的 SessionProposal 模型
      final proposal = SessionProposal(
        id: event.id,
        name: event.params.proposer.metadata.name,
        description: event.params.proposer.metadata.description,
        url: event.params.proposer.metadata.url,
        icons: event.params.proposer.metadata.icons,
      );

      final approved = await ConnectionRequestSheet.show(
        context: Get.context!,
        proposal: proposal,
        walletAddress: address,
      );

      debugPrint('📊 User response: $approved');

      if (approved == true) {
        // 获取请求的链
        final requiredNamespaces = event.params.requiredNamespaces;
        final chains = requiredNamespaces['eip155']?.chains ?? ['eip155:1'];

        await _wcService.approveSession(
          proposalId: event.id,
          address: address,
          chains: chains,
        );

        Toast.show('Connected to ${proposal.name}!');
        debugPrint('✅ Session approved: ${proposal.name}');

        // 刷新列表
        update();
      } else {
        await _wcService.rejectSession(proposalId: event.id);
        Toast.show('Connection rejected');
        debugPrint('❌ Session rejected by user');
      }
    } catch (e, stack) {
      debugPrint('❌ Handle connection request failed: $e');
      debugPrint('Stack: $stack');
      Toast.show('Connection failed: $e');
      try {
        await _wcService.rejectSession(
          proposalId: event.id,
          reason: 'Error: $e',
        );
      } catch (_)
    }
  }

  Future<void> _handleSessionRequest(SessionRequestEvent event) async {
    try {
      debugPrint('📨 Handling session request');
      debugPrint('   Method: ${event.method}');
      debugPrint('   Topic: ${event.topic}');

      // TODO: 根据 method 分发到不同的处理器
      switch (event.method) {
        case 'personal_sign':
        case 'eth_sign':
          await _handleSignRequest(event);
          break;

        case 'eth_sendTransaction':
        case 'eth_signTransaction':
          await _handleTransactionRequest(event);
          break;

        case 'eth_signTypedData':
        case 'eth_signTypedData_v4':
          await _handleTypedDataRequest(event);
          break;

        default:
          debugPrint('⚠️ Unsupported method: ${event.method}');
          await _wcService.respondError(
            topic: event.topic,
            requestId: event.id,
            error: 'Method not supported',
          );
          Toast.show('Method ${event.method} not supported yet');
      }
    } catch (e, stack) {
      debugPrint('❌ Handle session request failed: $e');
      debugPrint('Stack: $stack');
      await _wcService.respondError(
        topic: event.topic,
        requestId: event.id,
        error: e.toString(),
      );
    }
  }

  Future<void> _handleSignRequest(SessionRequestEvent event) async {
    // TODO: 显示签名确认界面并签名
    debugPrint('🖊️ Sign request (not implemented yet)');
    await _wcService.respondError(
      topic: event.topic,
      requestId: event.id,
      error: 'Sign not implemented yet',
    );
  }

  Future<void> _handleTransactionRequest(SessionRequestEvent event) async {
    // TODO: 显示交易确认界面并签名发送
    debugPrint('💸 Transaction request (not implemented yet)');
    await _wcService.respondError(
      topic: event.topic,
      requestId: event.id,
      error: 'Transaction not implemented yet',
    );
  }

  Future<void> _handleTypedDataRequest(SessionRequestEvent event) async {
    // TODO: 显示 TypedData 签名确认界面
    debugPrint('📝 TypedData request (not implemented yet)');
    await _wcService.respondError(
      topic: event.topic,
      requestId: event.id,
      error: 'TypedData not implemented yet',
    );
  }

  List<SessionData> getActiveSessions() => _wcService.getActiveSessions();

  Future<void> disconnectSession(String topic) async {
    await _wcService.disconnectSession(topic);
    update();
  }

  @override
  void onClose() {
    _proposalSubscription?.cancel();
    _requestSubscription?.cancel();
    super.onClose();
  }
}

/// 简化的 SessionProposal 模型（用于 UI）
class SessionProposal {
  final int id;
  final String name;
  final String description;
  final String url;
  final List<String> icons;

  SessionProposal({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.icons,
  });
}
