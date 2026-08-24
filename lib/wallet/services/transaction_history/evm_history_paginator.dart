part of '../wallet_transaction_history_service.dart';

/// Centralizes EVM scan windows and page sizing decisions.
class _EvmHistoryPaginator {
  static const int historyLimit = _transactionHistoryPageSize;
  static const int _bscExplorerPageSize = 100;
  static const int _bscExplorerMaxScanPages = 3;
  static const int logChunkSize = 50000;
  static const int _defaultLogPageBlockWindow = 500000;
  static const int _defaultLogScanBlockWindow = 5000000;
  static const int _xLayerLogScanBlockWindow = 500000;
  static const int _arbitrumLogScanBlockWindow = 200000;
  static const int blockscoutMaxPages = 4;

  int explorerRequestLimit(WalletChainRef chain) {
    return chain.id == WalletChain.bsc.id ? _bscExplorerPageSize : historyLimit;
  }

  int explorerScanPages(WalletChainRef chain) {
    return chain.id == WalletChain.bsc.id ? _bscExplorerMaxScanPages : 1;
  }

  int logScanBlockWindow(WalletChainRef chain) {
    if (chain.id == WalletChain.xLayer.id) {
      return _xLayerLogScanBlockWindow;
    }
    if (chain.id == WalletChain.arbitrum.id) {
      return _arbitrumLogScanBlockWindow;
    }
    return _defaultLogScanBlockWindow;
  }

  int logPageBlockWindow(WalletChainRef chain) {
    if (chain.id == WalletChain.arbitrum.id) {
      return _arbitrumLogScanBlockWindow;
    }
    return _defaultLogPageBlockWindow;
  }
}
