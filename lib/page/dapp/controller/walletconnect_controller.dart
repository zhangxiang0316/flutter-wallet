import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/walletconnect_service.dart';
import '../view/connection_request_sheet.dart';

/// WalletConnect 控制器
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
      await _wcService.initialize();
      _listenToEvents();
    } catch (e) {
      debugPrint('❌ WalletConnect initialization failed: $e');
    }
  }

  void _listenToEvents() {
    _wcService.onSessionProposal.listen((proposal) {
      _handleConnectionRequest(proposal);
    });
  }

  Future<void> _handleConnectionRequest(SessionProposal proposal) async {
    try {
      final wallet = await _repository.loadCurrentWallet();
      if (wallet == null) {
        await _wcService.rejectSession(proposalId: proposal.id, reason: 'No wallet');
        return;
      }

      final address = wallet.bscAddress;
      if (address.isEmpty) {
        await _wcService.rejectSession(proposalId: proposal.id, reason: 'No address');
        return;
      }

      final approved = await ConnectionRequestSheet.show(
        context: Get.context!,
        proposal: proposal,
        walletAddress: address,
      );

      if (approved == true) {
        await _wcService.approveSession(proposalId: proposal.id, address: address);
        debugPrint('✅ Session approved');
      } else {
        await _wcService.rejectSession(proposalId: proposal.id);
        debugPrint('❌ Session rejected');
      }
    } catch (e) {
      debugPrint('❌ Handle connection request failed: $e');
      await _wcService.rejectSession(proposalId: proposal.id, reason: 'Error: $e');
    }
  }

  List<String> getActiveSessions() => _wcService.getActiveSessions();

  Future<void> disconnectSession(String sessionId) async {
    await _wcService.disconnectSession(sessionId);
  }
}
