import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_transaction_record.dart';
import '../../../wallet/services/wallet_transaction_history_service.dart';

/// 交易记录页面参数。
///
/// 从首页点击某个币种进入时传入当前钱包 ID 和该币种余额信息，页面据此过滤交易记录。
class TransactionHistoryPageArguments {
  const TransactionHistoryPageArguments({
    required this.walletId,
    required this.asset,
  });

  /// 当前钱包 ID，用于隔离多钱包交易记录。
  final String walletId;

  /// 当前查看交易记录的币种。
  final ChainBalance asset;
}

/// 交易记录页面控制器。
///
/// 进入页面后直接请求链上/RPC 交易记录，不依赖转账时写入的本地缓存。
class TransactionHistoryController extends BaseController {
  TransactionHistoryController({
    WalletTransactionHistoryService? historyService,
  }) : _historyService = historyService ?? WalletTransactionHistoryService();

  final WalletTransactionHistoryService _historyService;

  /// 路由传入的当前钱包和资产参数。
  TransactionHistoryPageArguments? arguments;

  /// 当前资产的交易记录列表。
  List<WalletTransactionRecord> records = [];

  /// 是否正在读取交易记录。
  bool isLoading = false;

  /// 交易记录加载失败时展示的错误文案。
  String errorMessage = '';

  @override
  void onInit() {
    super.onInit();
    final value = Get.arguments;
    if (value is TransactionHistoryPageArguments) {
      arguments = value;
      loadRecords();
    }
  }

  /// 读取当前资产交易记录。
  Future<void> loadRecords() async {
    final args = arguments;
    if (args == null) return;
    try {
      isLoading = true;
      errorMessage = '';
      update();
      records = await _historyService.loadAssetRecords(
        walletId: args.walletId,
        asset: args.asset,
      );
    } catch (_) {
      errorMessage = S.current.transactionLoadFailed;
    } finally {
      isLoading = false;
      update();
    }
  }

  /// 复制交易哈希。
  void copyHash(WalletTransactionRecord record) {
    if (record.txHash.isEmpty) return;
    Clipboard.setData(ClipboardData(text: record.txHash));
    Toast.show(S.current.copied);
  }
}
