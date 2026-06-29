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
import '../../../wallet/services/wallet_transaction_status_service.dart';
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
    WalletTransactionStatusService? transactionStatusService,
    TransactionHistoryCache? cache,
  }) : _historyService = historyService ?? WalletTransactionHistoryService(),
       _blockExplorerService =
           blockExplorerService ?? const WalletBlockExplorerService(),
       _transactionStatusService =
           transactionStatusService ?? WalletTransactionStatusService(),
       _cache = cache ?? TransactionHistoryCache();

  final WalletTransactionHistoryService _historyService;
  final WalletBlockExplorerService _blockExplorerService;
  final WalletTransactionStatusService _transactionStatusService;
  final TransactionHistoryCache _cache;

  /// 路由传入的当前钱包和资产参数。
  TransactionHistoryPageArguments? arguments;

  /// 当前资产的交易记录列表。
  List<WalletTransactionRecord> records = [];

  /// 是否正在读取交易记录。
  bool isLoading = false;

  /// 是否正在加载更多历史记录。
  bool isLoadingMore = false;

  /// 当前数据源是否还有更多记录。
  bool hasMore = false;

  /// 下一页游标。
  TransactionHistoryCursor? _nextCursor;

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
    _nextCursor = null;
    hasMore = false;
    final local = await _loadAndRefreshLocalRecords(args);

    // ✅ 步骤 1: 立即显示缓存记录（如果有）
    final cached = await _cache.load(
      args.walletId,
      args.asset.chainId,
      args.asset.symbol,
      contractAddress: args.asset.contractAddress,
    );
    if (cached != null && cached.isNotEmpty) {
      records = _mergeRecords(local, cached);
      errorMessage = '';
      update(); // 立即显示缓存，用户感知 < 100ms
    } else if (local.isNotEmpty) {
      records = local;
      errorMessage = '';
      update();
    }

    // ✅ 步骤 2: 后台加载最新数据
    try {
      isLoading = true;
      errorMessage = '';
      update();

      final result = await _historyService.loadAssetRecordPage(
        walletId: args.walletId,
        asset: args.asset,
      );
      final fresh = result.records;

      if (fresh.isNotEmpty || records.isEmpty) {
        records = _mergeRecords(local, fresh);

        // ✅ 步骤 3: 保存新缓存
        await _cache.save(
          args.walletId,
          args.asset.chainId,
          args.asset.symbol,
          records,
          contractAddress: args.asset.contractAddress,
        );
      }
      _nextCursor = result.nextCursor;
      hasMore = result.hasMore;
    } catch (error) {
      if (records.isEmpty) {
        errorMessage = _historyLoadErrorMessage(error);
      } else {
        Toast.show(_historyLoadErrorMessage(error));
      }
    } finally {
      isLoading = false;
      update();
    }
  }

  /// 加载下一页交易记录。
  Future<void> loadMoreRecords() async {
    final args = arguments;
    final cursor = _nextCursor;
    if (args == null || cursor == null || isLoading || isLoadingMore) return;

    try {
      isLoadingMore = true;
      update();

      final result = await _historyService.loadAssetRecordPage(
        walletId: args.walletId,
        asset: args.asset,
        cursor: cursor,
      );
      records = _mergeRecords(records, result.records);
      _nextCursor = result.nextCursor;
      hasMore = result.hasMore;
      await _cache.save(
        args.walletId,
        args.asset.chainId,
        args.asset.symbol,
        records,
        contractAddress: args.asset.contractAddress,
      );
    } catch (error) {
      Toast.show(_historyLoadErrorMessage(error, isLoadMore: true));
    } finally {
      isLoadingMore = false;
      update();
    }
  }

  String _historyLoadErrorMessage(Object error, {bool isLoadMore = false}) {
    if (error is TransactionHistoryLoadException) {
      return switch (error.kind) {
        TransactionHistoryFailureKind.rateLimited =>
          S.current.transactionHistoryRateLimited,
        TransactionHistoryFailureKind.provider =>
          S.current.transactionHistoryProviderFailed,
      };
    }
    return isLoadMore
        ? S.current.transactionLoadMoreFailed
        : S.current.transactionLoadFailed;
  }

  List<WalletTransactionRecord> _mergeRecords(
    List<WalletTransactionRecord> current,
    List<WalletTransactionRecord> next,
  ) {
    if (next.isEmpty) return current;
    final seen = current.map(_recordMergeKey).toSet();
    final merged = [...current];
    for (final record in next) {
      final key = _recordMergeKey(record);
      final existingIndex = merged.indexWhere(
        (item) => _recordMergeKey(item) == key,
      );
      if (existingIndex >= 0) {
        merged[existingIndex] = _preferRecord(merged[existingIndex], record);
      } else if (seen.add(key)) {
        merged.add(record);
      }
    }
    merged.sort((left, right) {
      final leftTime = left.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightTime =
          right.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightTime.compareTo(leftTime);
    });
    return merged;
  }

  String _recordMergeKey(WalletTransactionRecord record) {
    final hash = record.txHash.trim().toLowerCase();
    if (hash.isNotEmpty) return hash;
    return record.id;
  }

  WalletTransactionRecord _preferRecord(
    WalletTransactionRecord current,
    WalletTransactionRecord next,
  ) {
    if (next.source == WalletTransactionSource.remote) return next;
    if (current.status == WalletTransactionStatus.pending &&
        next.status != WalletTransactionStatus.pending) {
      return next;
    }
    return current;
  }

  Future<List<WalletTransactionRecord>> _loadAndRefreshLocalRecords(
    TransactionHistoryPageArguments args,
  ) async {
    final local = await _cache.loadLocalRecords(
      args.walletId,
      args.asset.chainId,
      args.asset.symbol,
      contractAddress: args.asset.contractAddress,
    );
    if (local.isEmpty) return local;
    final refreshed = <WalletTransactionRecord>[];
    for (final record in local) {
      refreshed.add(await _refreshRecordStatus(record, showToast: false));
    }
    await _cache.saveLocalRecords(
      args.walletId,
      args.asset.chainId,
      args.asset.symbol,
      refreshed,
      contractAddress: args.asset.contractAddress,
    );
    return refreshed;
  }

  Future<WalletTransactionRecord> _refreshRecordStatus(
    WalletTransactionRecord record, {
    bool showToast = true,
  }) async {
    final asset = arguments?.asset;
    if (asset == null || record.txHash.isEmpty) return record;
    try {
      final status = await _transactionStatusService.loadStatus(
        chain: asset.chainRef,
        txHash: record.txHash,
      );
      final next = record.copyWith(status: status);
      await _cache.upsertLocalRecord(next);
      return next;
    } catch (_) {
      if (showToast) {
        Toast.show(S.current.transactionStatusRefreshFailed);
      }
      return record;
    }
  }

  Future<void> refreshRecordStatus(WalletTransactionRecord record) async {
    final next = await _refreshRecordStatus(record);
    records = records
        .map(
          (item) =>
              _recordMergeKey(item) == _recordMergeKey(record) ? next : item,
        )
        .toList(growable: false);
    update();
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

  Future<void> openTransactionExplorer(WalletTransactionRecord record) async {
    final asset = arguments?.asset;
    if (asset == null) return;
    final uri = _blockExplorerService.transactionUri(asset, record.txHash);
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
