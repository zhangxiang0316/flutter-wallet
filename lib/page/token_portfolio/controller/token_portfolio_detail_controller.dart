import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/route_table.dart';
import '../../../wallet/models/token_portfolio.dart';
import '../../transaction/controller/transaction_history_controller.dart';

class TokenPortfolioDetailPageArguments {
  const TokenPortfolioDetailPageArguments({
    required this.walletId,
    required this.item,
  });

  final String walletId;
  final TokenPortfolioItem item;
}

/// 代币多链详情控制器。
class TokenPortfolioDetailController extends BaseController {
  TokenPortfolioDetailPageArguments? arguments;

  TokenPortfolioItem? get item => arguments?.item;

  @override
  void onInit() {
    super.onInit();
    final value = Get.arguments;
    if (value is TokenPortfolioDetailPageArguments) {
      arguments = value;
    }
  }

  Future<void> openPositionHistory(TokenChainPosition position) async {
    final args = arguments;
    if (args == null) return;
    await Get.toNamed(
      RouteTable.transactionHistory,
      arguments: TransactionHistoryPageArguments(
        walletId: args.walletId,
        asset: position.balance,
      ),
    );
  }
}
