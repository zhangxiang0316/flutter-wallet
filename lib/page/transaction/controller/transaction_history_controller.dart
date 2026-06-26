import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../utils/toast_util.dart';
import '../../browser/controller/block_explorer_controller.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_transaction_record.dart';
import '../../../wallet/services/transaction_history_cache.dart';
import '../../../wallet/services/wallet_block_explorer_service.dart';
import '../../../wallet/services/wallet_transaction_history_service.dart';
import 'transaction_detail_controller.dart';

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
/// 优化策略：
/// 1. 立即显示缓存记录（< 50ms）
/// 2. 后台静默更新最新数据
/// 3. 自动保存新缓存供下次使用
class TransactionHistoryController extends BaseController {
  TransactionHistoryController({
    WalletTransactionHistoryService? historyService,
    WalletBlockExplorerService? blockExplorerService,
    TransactionHistoryCache? cache,
  }) : _historyService = historyService ?? WalletTransactionHistoryService(),
       _blockExplorerService =
           blockExplorerService ?? const WalletBlockExplorerService(),
       _cache = cache ?? TransactionHistoryCache();

  final WalletTransactionHistoryService _historyService;
  final WalletBlockExplorerService _blockExplorerService;
  final TransactionHistoryCache _cache;

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
  ///
  /// 优化策略：
  /// 1. 立即显示缓存（如果有）- 用户感知 < 100ms
  /// 2. 后台加载最新数据
  /// 3. 保存新缓存供下次使用
  Future<void> loadRecords() async {
    final args = arguments;
    if (args == null) return;

    // ✅ 步骤 1: 立即显示缓存记录（如果有）
    final cached = await _cache.load(
      args.walletId,
      args.asset.chainId,
      args.asset.symbol,
    );
    if (cached != null && cached.isNotEmpty) {
      records = cached;
      update(); // 立即显示缓存，用户感知 < 100ms
    }

    // ✅ 步骤 2: 后台加载最新数据
    try {
      isLoading = true;
      errorMessage = '';
      update();

      final fresh = await _historyService.loadAssetRecords(
        walletId: args.walletId,
        asset: args.asset,
      );

      records = fresh;

      // ✅ 步骤 3: 保存新缓存
      await _cache.save(
        args.walletId,
        args.asset.chainId,
        args.asset.symbol,
        fresh,
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

  /// 打开单条交易详情。
  Future<void> openRecordDetail(WalletTransactionRecord record) async {
    final asset = arguments?.asset;
    if (asset == null) return;
    await Get.toNamed(
      RouteTable.transactionDetail,
      arguments: TransactionDetailPageArguments(asset: asset, record: record),
    );
  }

  /// 打开应用内区块浏览器页面。
  Future<void> openBlockExplorer() async {
    final asset = arguments?.asset;
    if (asset == null) return;
    final uri = _blockExplorerService.addressUri(asset);
    if (uri == null) {
      Toast.show(S.current.blockExplorerUnavailable);
      return;
    }
    Get.toNamed(
      RouteTable.blockExplorer,
      arguments: BlockExplorerPageArguments(
        url: uri,
        title: asset.chainRef.name,
      ),
    );
  }
}
