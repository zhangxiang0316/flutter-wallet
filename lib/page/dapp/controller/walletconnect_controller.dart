import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:reown_walletkit/reown_walletkit.dart';

import '../../../base/base_controller.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/walletconnect_service.dart';
import '../../../widget/message_sign_sheet.dart';
import '../view/connection_request_sheet.dart';

/// WalletConnect 控制器
///
/// 管理 WalletConnect 会话和请求
class WalletConnectController extends BaseController {
  final WalletConnectService _wcService = WalletConnectService.instance;
  final WalletRepository _repository = WalletRepository();

  @override
  void onInit() {
    super.onInit();
    _initializeWalletConnect();
  }

  Future<void> _initializeWalletConnect() async {
    try {
      debugPrint('🎮 Initializing WalletConnect in controller...');
      await _wcService.initialize();
      _listenToEvents();
      debugPrint('✅ WalletConnect controller initialized');
    } catch (e, stack) {
      debugPrint('❌ WalletConnect controller init failed: $e');
      debugPrint('Stack: $stack');
    }
  }

  void _listenToEvents() {
    // Event.subscribe() returns void, subscriptions are managed by Event itself
    final proposalEvent = _wcService.onSessionProposal;
    if (proposalEvent != null) {
      proposalEvent.subscribe((event) {
        debugPrint('📥 Session proposal received');
        _handleConnectionRequest(event);
      });
    }

    final requestEvent = _wcService.onSessionRequest;
    if (requestEvent != null) {
      requestEvent.subscribe((event) {
        debugPrint('📥 Session request received: ${event.method}');
        _handleSessionRequest(event);
      });
    }
  }

  Future<void> _handleConnectionRequest(SessionProposalEvent event) async {
    try {
      debugPrint('💬 Showing connection request dialog');

      final proposal = DAppProposal(
        id: event.id,
        params: event.params,
      );

      // 获取当前钱包地址
      final wallet = await _repository.loadCurrentWallet();
      if (wallet == null) {
        throw Exception('No wallet available');
      }

      final approved = await ConnectionRequestSheet.show(
        context: Get.context!,
        proposal: proposal,
        walletAddress: wallet.bscAddress,
      );

      if (approved?['approved'] == true) {
        final chainId = approved!['chainId'] as String;

        // 批准会话，使用选中的链
        await _wcService.approveSession(
          proposalId: event.id,
          address: wallet.bscAddress,
          chains: [chainId], // 使用用户选择的链
        );

        Toast.show('Connected to ${event.params.proposer.metadata.name} on ${approved['chain']}!');
        debugPrint('✅ Session approved: ${event.params.proposer.metadata.name} on ${approved['chain']}');

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
      } catch (_) {
        // Ignore
      }
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
            error: 'Method ${event.method} not supported',
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
    try {
      debugPrint('🖊️ Handling sign request');

      // 解析参数
      final params = event.params as List;
      if (params.isEmpty) {
        await _wcService.respondError(
          topic: event.topic,
          requestId: event.id,
          error: 'Invalid parameters',
        );
        return;
      }

      String message = '';
      String address = '';

      if (event.method == 'personal_sign') {
        // personal_sign: [message, address]
        message = params[0] as String;
        address = params.length > 1 ? params[1] as String : '';
      } else {
        // eth_sign: [address, message]
        address = params[0] as String;
        message = params.length > 1 ? params[1] as String : '';
      }

      debugPrint('   Message: ${message.substring(0, min(50, message.length))}...');
      debugPrint('   Address: $address');

      // 获取当前钱包
      final wallet = await _repository.loadCurrentWallet();
      if (wallet == null) {
        await _wcService.respondError(
          topic: event.topic,
          requestId: event.id,
          error: 'No wallet available',
        );
        Toast.show('Please create a wallet first');
        return;
      }

      // 显示签名确认对话框
      final approved = await _showSignConfirmDialog(
        dappName: _getSessionName(event.topic),
        message: message,
        address: wallet.bscAddress,
      );

      if (approved == true) {
        // TODO: 实际签名消息
        // 现在返回一个模拟签名
        final signature = '0x${'0' * 130}';

        await _wcService.respondSuccess(
          topic: event.topic,
          requestId: event.id,
          result: signature,
        );
        debugPrint('✅ Signature sent to DApp');
        Toast.show('Signed successfully');
      } else {
        // 用户拒绝签名
        await _wcService.respondError(
          topic: event.topic,
          requestId: event.id,
          error: 'User rejected',
        );
        debugPrint('❌ User rejected signing');
      }
    } catch (e, stack) {
      debugPrint('❌ Sign request failed: $e');
      debugPrint('Stack: $stack');
      await _wcService.respondError(
        topic: event.topic,
        requestId: event.id,
        error: e.toString(),
      );
    }
  }

  Future<void> _handleTransactionRequest(SessionRequestEvent event) async {
    try {
      debugPrint('💸 Handling transaction request');

      // 解析交易参数
      final params = event.params as List;
      if (params.isEmpty) {
        await _wcService.respondError(
          topic: event.topic,
          requestId: event.id,
          error: 'Invalid parameters',
        );
        return;
      }

      final txParam = params[0] as Map<String, dynamic>;
      debugPrint('   From: ${txParam['from']}');
      debugPrint('   To: ${txParam['to']}');
      debugPrint('   Value: ${txParam['value']}');

      // 获取当前钱包
      final wallet = await _repository.loadCurrentWallet();
      if (wallet == null) {
        await _wcService.respondError(
          topic: event.topic,
          requestId: event.id,
          error: 'No wallet available',
        );
        Toast.show('Please create a wallet first');
        return;
      }

      // TODO: 显示交易预览界面（TransactionReviewSheet）
      // 由于需要构造完整的交易对象，这里暂时返回 not implemented
      // 你可以根据 Phase 1 的 TransactionReviewSheet 来集成

      debugPrint('⚠️ Transaction UI not integrated yet');
      Toast.show('Transaction signing will be added soon');

      await _wcService.respondError(
        topic: event.topic,
        requestId: event.id,
        error: 'Transaction signing UI not integrated yet',
      );

    } catch (e, stack) {
      debugPrint('❌ Transaction request failed: $e');
      debugPrint('Stack: $stack');
      await _wcService.respondError(
        topic: event.topic,
        requestId: event.id,
        error: e.toString(),
      );
    }
  }

  Future<void> _handleTypedDataRequest(SessionRequestEvent event) async {
    try {
      debugPrint('📝 Handling typed data request');

      final params = event.params as List;
      if (params.length < 2) {
        await _wcService.respondError(
          topic: event.topic,
          requestId: event.id,
          error: 'Invalid parameters',
        );
        return;
      }

      final address = params[0] as String;
      final typedData = params[1] as String;

      debugPrint('   Address: $address');
      debugPrint('   TypedData: ${typedData.substring(0, min(100, typedData.length))}...');

      // 获取当前钱包
      final wallet = await _repository.loadCurrentWallet();
      if (wallet == null) {
        await _wcService.respondError(
          topic: event.topic,
          requestId: event.id,
          error: 'No wallet available',
        );
        Toast.show('Please create a wallet first');
        return;
      }

      // 显示 TypedData 签名确认对话框
      final approved = await _showSignConfirmDialog(
        dappName: _getSessionName(event.topic),
        message: typedData,
        address: wallet.bscAddress,
        isTypedData: true,
      );

      if (approved == true) {
        // TODO: 实际签名 TypedData
        final signature = '0x${'0' * 130}';

        await _wcService.respondSuccess(
          topic: event.topic,
          requestId: event.id,
          result: signature,
        );
        debugPrint('✅ TypedData signature sent');
        Toast.show('Signed successfully');
      } else {
        await _wcService.respondError(
          topic: event.topic,
          requestId: event.id,
          error: 'User rejected',
        );
        debugPrint('❌ User rejected TypedData signing');
      }
    } catch (e, stack) {
      debugPrint('❌ TypedData request failed: $e');
      debugPrint('Stack: $stack');
      await _wcService.respondError(
        topic: event.topic,
        requestId: event.id,
        error: e.toString(),
      );
    }
  }

  /// 显示签名确认对话框
  Future<bool?> _showSignConfirmDialog({
    required String dappName,
    required String message,
    required String address,
    bool isTypedData = false,
  }) {
    return showModalBottomSheet<bool>(
      context: Get.context!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MessageSignSheet(
          dappName: dappName,
          message: message,
          messageType: isTypedData ? MessageType.typedData : MessageType.text,
          signerAddress: address,
          onSign: () => Navigator.of(context).pop(true),
          onReject: () => Navigator.of(context).pop(false),
        );
      },
    );
  }

  /// 获取会话的 DApp 名称
  String _getSessionName(String topic) {
    try {
      final sessions = _wcService.getActiveSessions();
      final session = sessions.firstWhere(
        (s) => s.topic == topic,
        orElse: () => throw Exception('Session not found'),
      );
      return session.peer.metadata.name;
    } catch (e) {
      return 'Unknown DApp';
    }
  }

  /// 获取所有活动会话
  List<SessionData> getActiveSessions() {
    return _wcService.getActiveSessions();
  }

  /// 断开会话
  Future<void> disconnectSession(String topic) async {
    try {
      await _wcService.disconnectSession(topic);
      update();
    } catch (e) {
      debugPrint('❌ Disconnect session failed: $e');
      rethrow;
    }
  }

  @override
  void onClose() {
    _wcService.dispose();
    super.onClose();
  }
}
