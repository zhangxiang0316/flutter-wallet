import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/walletconnect_service.dart';
import '../view/connection_request_sheet.dart';

/// WalletConnect 控制器
class WalletConnectController extends BaseController {
  final WalletConnectService _wcService = WalletConnectService.instance;
  final WalletRepository _repository = WalletRepository();

  StreamSubscription? _proposalSubscription;

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
    }
  }

  void _listenToEvents() {
    // 取消之前的订阅，防止重复
    _proposalSubscription?.cancel();

    _proposalSubscription = _wcService.onSessionProposal.listen((proposal) {
      _handleConnectionRequest(proposal);
    });
  }

  Future<void> _handleConnectionRequest(SessionProposal proposal) async {
    try {
      debugPrint('📥 Handling connection request for: ${proposal.name}');

      final wallet = await _repository.loadCurrentWallet();
      if (wallet == null) {
        debugPrint('❌ No wallet available');
        await _wcService.rejectSession(proposalId: proposal.id, reason: 'No wallet');
        Toast.show('Please create a wallet first');
        return;
      }

      final address = wallet.bscAddress;
      if (address.isEmpty) {
        debugPrint('❌ No wallet address');
        await _wcService.rejectSession(proposalId: proposal.id, reason: 'No address');
        Toast.show('No wallet address');
        return;
      }

      debugPrint('💬 Showing connection request dialog...');
      debugPrint('   DApp: ${proposal.name}');
      debugPrint('   Address: $address');

      final approved = await ConnectionRequestSheet.show(
        context: Get.context!,
        proposal: proposal,
        walletAddress: address,
      );

      debugPrint('📊 User response: $approved');

      if (approved == true) {
        await _wcService.approveSession(proposalId: proposal.id, address: address);
        Toast.show('Connected to ${proposal.name}!');
        debugPrint('✅ Session approved: ${proposal.name}');

        // 刷新列表
        update();
      } else {
        await _wcService.rejectSession(proposalId: proposal.id);
        Toast.show('Connection rejected');
        debugPrint('❌ Session rejected by user');
      }
    } catch (e) {
      debugPrint('❌ Handle connection request failed: $e');
      Toast.show('Connection failed: $e');
      await _wcService.rejectSession(proposalId: proposal.id, reason: 'Error: $e');
    }
  }

  List<String> getActiveSessions() => _wcService.getActiveSessions();

  Future<void> disconnectSession(String sessionId) async {
    await _wcService.disconnectSession(sessionId);
    update();
  }

  @override
  void onClose() {
    _proposalSubscription?.cancel();
    super.onClose();
  }
}
