import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_transaction_record.dart';
import '../../../wallet/services/transaction/wallet_block_explorer_service.dart';
import '../../browser/controller/block_explorer_controller.dart';

/// 交易详情页面参数。
class TransactionDetailPageArguments {
  const TransactionDetailPageArguments({
    required this.asset,
    required this.record,
  });

  final ChainBalance asset;
  final WalletTransactionRecord record;
}

/// 交易详情控制器。
class TransactionDetailController extends BaseController {
  TransactionDetailController({
    WalletBlockExplorerService? blockExplorerService,
  }) : _blockExplorerService =
           blockExplorerService ?? const WalletBlockExplorerService();

  final WalletBlockExplorerService _blockExplorerService;

  TransactionDetailPageArguments? arguments;

  WalletTransactionRecord? get record => arguments?.record;

  ChainBalance? get asset => arguments?.asset;

  @override
  void onInit() {
    super.onInit();
    final value = Get.arguments;
    if (value is TransactionDetailPageArguments) {
      arguments = value;
    }
  }

  Future<void> copyText(String value) async {
    final text = value.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    Toast.show(S.current.copied);
  }

  Future<void> openTransactionExplorer() async {
    final currentAsset = asset;
    final currentRecord = record;
    if (currentAsset == null || currentRecord == null) return;
    final uri = _blockExplorerService.transactionUri(
      currentAsset,
      currentRecord.txHash,
    );
    if (uri == null) {
      Toast.show(S.current.blockExplorerUnavailable);
      return;
    }
    Get.toNamed(
      RouteTable.blockExplorer,
      arguments: BlockExplorerPageArguments(
        url: uri,
        title: currentRecord.chainName,
      ),
    );
  }
}
