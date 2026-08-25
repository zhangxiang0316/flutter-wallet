import '../models/wallet_account.dart';

/// 钱包持久化事务类型。
enum WalletPersistenceOperation { upsert, remove }

/// 钱包持久化事务当前阶段。
///
/// 每个会改变跨存储状态的步骤都会先记录 journal。应用被中断后，仓储可以根据
/// 阶段选择回滚旧状态或完成已经提交的操作。
enum WalletPersistencePhase {
  pending,
  secretsPrepared,
  metadataCommitPending,
  metadataCommitted,
  cleanupPending,
  rollbackPending,
}

/// 不包含任何明文密钥的钱包持久化 journal。
class WalletPersistenceTransaction {
  const WalletPersistenceTransaction({
    required this.id,
    required this.operation,
    required this.phase,
    required this.walletId,
    required this.stagingWalletId,
    required this.backupWalletId,
    required this.previousWallets,
    required this.createdAt,
    this.previousCurrentWalletId,
    this.hadExistingSecrets = false,
    this.metadataMayHaveChanged = false,
  });

  static const String journalStorageKey = 'wallet_persistence_transaction_v1';

  final String id;
  final WalletPersistenceOperation operation;
  final WalletPersistencePhase phase;
  final String walletId;
  final String stagingWalletId;
  final String backupWalletId;
  final List<WalletAccount> previousWallets;
  final String? previousCurrentWalletId;
  final bool hadExistingSecrets;
  final bool metadataMayHaveChanged;
  final DateTime createdAt;

  WalletPersistenceTransaction copyWith({
    WalletPersistencePhase? phase,
    bool? hadExistingSecrets,
    bool? metadataMayHaveChanged,
  }) {
    return WalletPersistenceTransaction(
      id: id,
      operation: operation,
      phase: phase ?? this.phase,
      walletId: walletId,
      stagingWalletId: stagingWalletId,
      backupWalletId: backupWalletId,
      previousWallets: previousWallets,
      previousCurrentWalletId: previousCurrentWalletId,
      hadExistingSecrets: hadExistingSecrets ?? this.hadExistingSecrets,
      metadataMayHaveChanged:
          metadataMayHaveChanged ?? this.metadataMayHaveChanged,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'id': id,
      'operation': operation.name,
      'phase': phase.name,
      'walletId': walletId,
      'stagingWalletId': stagingWalletId,
      'backupWalletId': backupWalletId,
      'previousWallets': previousWallets
          .map((wallet) => wallet.toJson())
          .toList(growable: false),
      'previousCurrentWalletId': previousCurrentWalletId,
      'hadExistingSecrets': hadExistingSecrets,
      'metadataMayHaveChanged': metadataMayHaveChanged,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WalletPersistenceTransaction.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported wallet transaction version');
    }
    final operationName = json['operation']?.toString();
    final phaseName = json['phase']?.toString();
    final operation = WalletPersistenceOperation.values.where(
      (value) => value.name == operationName,
    );
    final phase = WalletPersistencePhase.values.where(
      (value) => value.name == phaseName,
    );
    final previousWallets = json['previousWallets'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (operation.isEmpty ||
        phase.isEmpty ||
        previousWallets is! List ||
        createdAt == null) {
      throw const FormatException('Invalid wallet transaction journal');
    }
    final id = json['id']?.toString() ?? '';
    final walletId = json['walletId']?.toString() ?? '';
    final stagingWalletId = json['stagingWalletId']?.toString() ?? '';
    final backupWalletId = json['backupWalletId']?.toString() ?? '';
    if (id.isEmpty ||
        walletId.isEmpty ||
        stagingWalletId.isEmpty ||
        backupWalletId.isEmpty) {
      throw const FormatException('Incomplete wallet transaction journal');
    }
    final parsedWallets = previousWallets
        .whereType<Map>()
        .map((item) => WalletAccount.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    if (parsedWallets.length != previousWallets.length) {
      throw const FormatException('Invalid previous wallet snapshot');
    }
    return WalletPersistenceTransaction(
      id: id,
      operation: operation.single,
      phase: phase.single,
      walletId: walletId,
      stagingWalletId: stagingWalletId,
      backupWalletId: backupWalletId,
      previousWallets: parsedWallets,
      previousCurrentWalletId: json['previousCurrentWalletId']?.toString(),
      hadExistingSecrets: json['hadExistingSecrets'] == true,
      metadataMayHaveChanged: json['metadataMayHaveChanged'] == true,
      createdAt: createdAt,
    );
  }
}
