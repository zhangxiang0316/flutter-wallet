import '../../models/wallet_transaction_record.dart';

/// 交易记录合并和本地/远程对账规则。
///
/// 远程事件和本地提交是两类不同实体：远程 Token Transfer 以交易哈希和事件序号
/// 唯一标识；本地提交以资产和交易哈希（无哈希旧数据回退到 ID）标识。远程已索引到
/// 同一链、同一资产、同一交易哈希后，本地占位记录才会被移除。
class TransactionRecordMerger {
  const TransactionRecordMerger();

  List<WalletTransactionRecord> merge(
    Iterable<WalletTransactionRecord> current,
    Iterable<WalletTransactionRecord> next,
  ) {
    final remoteByKey = <String, WalletTransactionRecord>{};
    final localByKey = <String, WalletTransactionRecord>{};

    for (final record in [...current, ...next]) {
      final records = record.source == WalletTransactionSource.remote
          ? remoteByKey
          : localByKey;
      final key = record.source == WalletTransactionSource.remote
          ? _remoteEventKey(record)
          : _localSubmissionKey(record);
      final existing = records[key];
      records[key] = existing == null
          ? record
          : withMonotonicStatus(existing, record);
    }

    final remoteRecords = remoteByKey.values.toList(growable: false);
    final localRecords = localByKey.values.where((local) {
      return !remoteRecords.any((remote) => _reconciles(local, remote));
    });
    final merged = [...localRecords, ...remoteRecords];
    merged.sort(_compareTimeDesc);
    return merged;
  }

  /// 保留已经确定的终态，只允许 pending/unknown 向 success/failed 前进。
  static WalletTransactionRecord withMonotonicStatus(
    WalletTransactionRecord current,
    WalletTransactionRecord next,
  ) {
    final currentIsFinal = _isFinal(current.status);
    final nextIsFinal = _isFinal(next.status);
    if (currentIsFinal) {
      return next.copyWith(status: current.status);
    }
    if (!nextIsFinal) {
      return next.copyWith(status: current.status);
    }
    return next;
  }

  String _remoteEventKey(WalletTransactionRecord record) {
    final hash = _normalizedHash(record);
    final assetKey = record.assetKey.toLowerCase();
    final eventIndex = record.eventIndex?.trim();
    if (hash.isNotEmpty && eventIndex != null && eventIndex.isNotEmpty) {
      return 'remote:$assetKey:$hash:event:$eventIndex';
    }
    if (hash.isNotEmpty && (record.contractAddress?.trim().isEmpty ?? true)) {
      return 'remote:$assetKey:$hash';
    }

    // 旧缓存没有 eventIndex 时保留 provider 生成的事件 ID，避免重新退化为仅按
    // hash 合并而丢失同一交易内的多条 Token Transfer。
    final id = record.id.trim();
    return id.isNotEmpty ? 'remote-id:$id' : 'remote:$assetKey:$hash';
  }

  String _localSubmissionKey(WalletTransactionRecord record) {
    final hash = _normalizedHash(record);
    if (hash.isNotEmpty) {
      return 'local:${record.assetKey.toLowerCase()}:$hash';
    }
    final id = record.id.trim();
    if (id.isNotEmpty) return 'local-id:$id';
    return 'local:${record.assetKey.toLowerCase()}:missing-hash';
  }

  bool _reconciles(
    WalletTransactionRecord local,
    WalletTransactionRecord remote,
  ) {
    final localHash = _normalizedHash(local);
    return localHash.isNotEmpty &&
        localHash == _normalizedHash(remote) &&
        local.assetKey.toLowerCase() == remote.assetKey.toLowerCase();
  }

  String _normalizedHash(WalletTransactionRecord record) {
    return record.txHash.trim().toLowerCase();
  }

  int _compareTimeDesc(
    WalletTransactionRecord left,
    WalletTransactionRecord right,
  ) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return (right.timestamp ?? epoch).compareTo(left.timestamp ?? epoch);
  }

  static bool _isFinal(WalletTransactionStatus status) {
    return status == WalletTransactionStatus.success ||
        status == WalletTransactionStatus.failed;
  }
}
