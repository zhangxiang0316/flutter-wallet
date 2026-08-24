import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_transaction_record.dart';
import '../../../wallet/services/wallet_transfer_service.dart';

import 'transfer_controller.dart';

/// 转账页面的临时状态集合。
///
/// 将表单、预估费用和已提交交易状态集中管理，避免 Controller 同时承担大量
/// 独立字段和状态重置逻辑。
class TransferPageState {
  TransferPageArguments? arguments;
  List<ChainBalance> availableAssets = [];
  ChainBalance? selectedAsset;
  bool isSubmitting = false;
  bool isEstimatingFee = false;
  bool feeEstimateUnavailable = false;
  TransferFeeEstimate? feeEstimate;
  List<String> recipientHistoryAddresses = const [];
  String transactionHash = '';
  String? scannedPaymentMemo;
  String? paymentRequestAddress;
  WalletTransactionStatus submittedStatus = WalletTransactionStatus.unknown;
}
