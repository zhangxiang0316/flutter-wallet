/// 交易方向。
enum WalletTransactionDirection { incoming, outgoing, selfTransfer, unknown }

/// 交易状态。
enum WalletTransactionStatus { success, failed, pending, unknown }

/// 交易记录来源。
enum WalletTransactionSource { local, remote }

/// 钱包交易记录统一模型。
///
/// 不同链返回的交易结构差异很大，页面只消费这层归一化后的字段。当前记录既可以
/// 来自本地提交缓存，也可以来自链上 RPC/浏览器接口。
class WalletTransactionRecord {
  const WalletTransactionRecord({
    required this.id,
    required this.walletId,
    required this.chainId,
    required this.chainName,
    required this.symbol,
    required this.assetName,
    required this.walletAddress,
    required this.txHash,
    required this.fromAddress,
    required this.toAddress,
    required this.amount,
    required this.decimals,
    required this.direction,
    required this.status,
    required this.source,
    this.eventIndex,
    this.contractAddress,
    this.feeAmount,
    this.feeSymbol,
    this.blockNumber,
    this.timestamp,
  });

  final String id;
  final String walletId;
  final String chainId;
  final String chainName;
  final String symbol;
  final String assetName;
  final String walletAddress;
  final String txHash;
  final String fromAddress;
  final String toAddress;
  final String amount;
  final int decimals;
  final WalletTransactionDirection direction;
  final WalletTransactionStatus status;
  final WalletTransactionSource source;

  /// 链上交易内的事件序号。
  ///
  /// Token Transfer 等一笔交易可产生多条事件，远程记录使用该字段与 [txHash]
  /// 组成稳定唯一键。原生转账和本地提交记录通常为空。
  final String? eventIndex;
  final String? contractAddress;
  final String? feeAmount;
  final String? feeSymbol;
  final int? blockNumber;
  final DateTime? timestamp;

  bool get isOutgoing => direction == WalletTransactionDirection.outgoing;

  WalletTransactionRecord copyWith({
    WalletTransactionStatus? status,
    WalletTransactionSource? source,
    String? feeAmount,
    String? feeSymbol,
    int? blockNumber,
    DateTime? timestamp,
  }) {
    return WalletTransactionRecord(
      id: id,
      walletId: walletId,
      chainId: chainId,
      chainName: chainName,
      symbol: symbol,
      assetName: assetName,
      walletAddress: walletAddress,
      txHash: txHash,
      fromAddress: fromAddress,
      toAddress: toAddress,
      amount: amount,
      decimals: decimals,
      direction: direction,
      status: status ?? this.status,
      source: source ?? this.source,
      eventIndex: eventIndex,
      contractAddress: contractAddress,
      feeAmount: feeAmount ?? this.feeAmount,
      feeSymbol: feeSymbol ?? this.feeSymbol,
      blockNumber: blockNumber ?? this.blockNumber,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  String get assetKey {
    final contract = contractAddress?.trim() ?? '';
    return [
      chainId,
      contract.isEmpty ? 'native' : contract,
      symbol.toUpperCase(),
    ].join(':');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletId': walletId,
      'chainId': chainId,
      'chainName': chainName,
      'symbol': symbol,
      'assetName': assetName,
      'walletAddress': walletAddress,
      'txHash': txHash,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'amount': amount,
      'decimals': decimals,
      'direction': direction.name,
      'status': status.name,
      'source': source.name,
      'eventIndex': eventIndex,
      'contractAddress': contractAddress,
      'feeAmount': feeAmount,
      'feeSymbol': feeSymbol,
      'blockNumber': blockNumber,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  factory WalletTransactionRecord.fromJson(Map<String, dynamic> json) {
    return WalletTransactionRecord(
      id: json['id']?.toString() ?? '',
      walletId: json['walletId']?.toString() ?? '',
      chainId: json['chainId']?.toString() ?? '',
      chainName: json['chainName']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      assetName: json['assetName']?.toString() ?? '',
      walletAddress: json['walletAddress']?.toString() ?? '',
      txHash: json['txHash']?.toString() ?? '',
      fromAddress: json['fromAddress']?.toString() ?? '',
      toAddress: json['toAddress']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      decimals: int.tryParse(json['decimals']?.toString() ?? '') ?? 0,
      direction: _enumByName(
        WalletTransactionDirection.values,
        json['direction']?.toString(),
        WalletTransactionDirection.unknown,
      ),
      status: _enumByName(
        WalletTransactionStatus.values,
        json['status']?.toString(),
        WalletTransactionStatus.unknown,
      ),
      source: _enumByName(
        WalletTransactionSource.values,
        json['source']?.toString(),
        WalletTransactionSource.local,
      ),
      eventIndex: json['eventIndex']?.toString(),
      contractAddress: json['contractAddress']?.toString(),
      feeAmount: json['feeAmount']?.toString(),
      feeSymbol: json['feeSymbol']?.toString(),
      blockNumber: int.tryParse(json['blockNumber']?.toString() ?? ''),
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
    );
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }
}
