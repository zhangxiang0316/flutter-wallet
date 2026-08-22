import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../utils/toast_util.dart';
import '../../browser/controller/block_explorer_controller.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_transaction_record.dart';
import '../../../wallet/services/transaction/transaction_history_cache.dart';
import '../../../wallet/services/transaction/transaction_record_merger.dart';
import '../../../wallet/services/transaction/wallet_block_explorer_service.dart';
import '../../../wallet/services/transaction/wallet_transaction_status_service.dart';
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
           blockExplorerService ?? WalletBlockExplorerService(),
       _transactionStatusService =
           transactionStatusService ?? WalletTransactionStatusService(),
       _cache = cache ?? TransactionHistoryCache();

  final WalletTransactionHistoryService _historyService;
  final WalletBlockExplorerService _blockExplorerService;
  final WalletTransactionStatusService _transactionStatusService;
  final TransactionHistoryCache _cache;
  final TransactionRecordMerger _recordMerger = const TransactionRecordMerger();

  /// pending 状态查询的最大并发数，避免进入页面时同时压满 RPC 节点。
  static const int _statusRefreshConcurrency = 3;

  /// 首屏加载版本号，用于忽略快速切换资产后返回的旧异步结果。
  int _loadRequestId = 0;

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
    final requestId = ++_loadRequestId;
    _nextCursor = null;
    hasMore = false;
    isLoading = true;
    errorMessage = '';
    update();

    // 普通缓存和本地提交缓存同时读取。此处不等待任何链上状态请求，存储返回后
    // 立即绘制首屏；pending 刷新会在下方作为独立后台任务启动。
    final cachedFuture = _cache.load(
      args.walletId,
      args.asset.chainId,
      args.asset.symbol,
      contractAddress: args.asset.contractAddress,
    );
    final localFuture = _cache.loadLocalRecords(
      args.walletId,
      args.asset.chainId,
      args.asset.symbol,
      contractAddress: args.asset.contractAddress,
    );
    final cached = await cachedFuture;
    final local = await localFuture;
    if (!_isActiveLoad(requestId, args)) return;

    final cachedRemote = (cached ?? const <WalletTransactionRecord>[]).where(
      (record) => record.source == WalletTransactionSource.remote,
    );
    records = _recordMerger.merge(local, cachedRemote);
    if (records.isNotEmpty) {
      errorMessage = '';
      update();
    }
    unawaited(_refreshPendingLocalRecords(args, local, requestId));

    // 缓存已经可见后，再请求远程第一页并更新普通缓存。
    try {
      final result = await _historyService.loadAssetRecordPage(
        walletId: args.walletId,
        asset: args.asset,
      );
      if (!_isActiveLoad(requestId, args)) return;
      final fresh = result.records;

      if (fresh.isNotEmpty || records.isEmpty) {
        final visibleLocal = records.where(
          (record) => record.source == WalletTransactionSource.local,
        );
        records = _recordMerger.merge(visibleLocal, fresh);
        await _cache.save(
          args.walletId,
          args.asset.chainId,
          args.asset.symbol,
          records
              .where(
                (record) => record.source == WalletTransactionSource.remote,
              )
              .toList(growable: false),
          contractAddress: args.asset.contractAddress,
        );
      }
      _nextCursor = result.nextCursor;
      hasMore = result.hasMore;
    } catch (error) {
      if (!_isActiveLoad(requestId, args)) return;
      if (records.isEmpty) {
        errorMessage = _historyLoadErrorMessage(error);
      } else {
        Toast.show(_historyLoadErrorMessage(error));
      }
    } finally {
      if (_isActiveLoad(requestId, args)) {
        isLoading = false;
        update();
      }
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
      records = _recordMerger.merge(records, result.records);
      _nextCursor = result.nextCursor;
      hasMore = result.hasMore;
      await _cache.save(
        args.walletId,
        args.asset.chainId,
        args.asset.symbol,
        records
            .where((record) => record.source == WalletTransactionSource.remote)
            .toList(growable: false),
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
        TransactionHistoryFailureKind.noRecords =>
          S.current.transactionHistoryNoRecords,
        TransactionHistoryFailureKind.rateLimited =>
          S.current.transactionHistoryRateLimited,
        TransactionHistoryFailureKind.apiKeyMissing =>
          S.current.transactionHistoryApiKeyMissing,
        TransactionHistoryFailureKind.apiKeyInvalid =>
          S.current.transactionHistoryApiKeyInvalid,
        TransactionHistoryFailureKind.timeout =>
          S.current.transactionHistoryTimeout,
        TransactionHistoryFailureKind.providerFailed =>
          S.current.transactionHistoryProviderFailed,
      };
    }
    return isLoadMore
        ? S.current.transactionLoadMoreFailed
        : S.current.transactionLoadFailed;
  }

  Future<void> _refreshPendingLocalRecords(
    TransactionHistoryPageArguments args,
    List<WalletTransactionRecord> local,
    int requestId,
  ) async {
    final pending = local
        .where(
          (record) =>
              record.source == WalletTransactionSource.local &&
              record.status == WalletTransactionStatus.pending &&
              record.txHash.trim().isNotEmpty,
        )
        .toList(growable: false);
    if (pending.isEmpty) return;

    final refreshedLocal = [...local];
    for (
      var start = 0;
      start < pending.length;
      start += _statusRefreshConcurrency
    ) {
      final end = start + _statusRefreshConcurrency < pending.length
          ? start + _statusRefreshConcurrency
          : pending.length;
      final batch = pending.sublist(start, end);
      final refreshed = await Future.wait(
        batch.map(
          (record) =>
              _refreshRecordStatus(record, showToast: false, persist: false),
        ),
      );
      if (!_isActiveLoad(requestId, args)) return;

      for (final next in refreshed) {
        final index = refreshedLocal.indexWhere(
          (record) => _sameLocalSubmission(record, next),
        );
        if (index >= 0) {
          refreshedLocal[index] = TransactionRecordMerger.withMonotonicStatus(
            refreshedLocal[index],
            next,
          );
        }
      }
      records = _recordMerger.merge(records, refreshed);
      update();
    }
    await _cache.saveLocalRecords(
      args.walletId,
      args.asset.chainId,
      args.asset.symbol,
      refreshedLocal,
      contractAddress: args.asset.contractAddress,
    );
  }

  Future<WalletTransactionRecord> _refreshRecordStatus(
    WalletTransactionRecord record, {
    bool showToast = true,
    bool persist = true,
  }) async {
    final asset = arguments?.asset;
    if (asset == null ||
        record.source != WalletTransactionSource.local ||
        record.status != WalletTransactionStatus.pending ||
        record.txHash.isEmpty) {
      return record;
    }
    try {
      final status = await _transactionStatusService.loadStatus(
        chain: asset.chainRef,
        txHash: record.txHash,
      );
      if (status != WalletTransactionStatus.success &&
          status != WalletTransactionStatus.failed) {
        return record;
      }
      final next = record.copyWith(status: status);
      if (persist) {
        await _cache.upsertLocalRecord(next);
      }
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
    records = _recordMerger.merge(records, [next]);
    update();
  }

  bool _sameLocalSubmission(
    WalletTransactionRecord left,
    WalletTransactionRecord right,
  ) {
    if (left.id.isNotEmpty && right.id.isNotEmpty) {
      return left.id == right.id;
    }
    return left.txHash.trim().toLowerCase() ==
        right.txHash.trim().toLowerCase();
  }

  bool _isActiveLoad(int requestId, TransactionHistoryPageArguments args) {
    return requestId == _loadRequestId && identical(arguments, args);
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
