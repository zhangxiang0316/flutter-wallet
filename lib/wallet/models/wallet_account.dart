class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.name,
    required this.bscAddress,
    required this.tronAddress,
    required this.createdAt,
    this.solanaAddress = '',
    this.suiAddress = '',
    this.aptosAddress = '',
    this.bitcoinAddress = '',
    this.privateKeyHex = '',
  });

  final String id;
  final String name;

  /// Only populated for legacy wallets that were saved before secure storage.
  final String privateKeyHex;
  final String bscAddress;
  final String tronAddress;
  final String solanaAddress;
  final String suiAddress;
  final String aptosAddress;
  final String bitcoinAddress;
  final DateTime createdAt;

  bool get needsSecretMigration => privateKeyHex.isNotEmpty;

  WalletAccount copyWith({
    String? id,
    String? name,
    String? privateKeyHex,
    String? bscAddress,
    String? tronAddress,
    String? solanaAddress,
    String? suiAddress,
    String? aptosAddress,
    String? bitcoinAddress,
    DateTime? createdAt,
  }) {
    return WalletAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      privateKeyHex: privateKeyHex ?? this.privateKeyHex,
      bscAddress: bscAddress ?? this.bscAddress,
      tronAddress: tronAddress ?? this.tronAddress,
      solanaAddress: solanaAddress ?? this.solanaAddress,
      suiAddress: suiAddress ?? this.suiAddress,
      aptosAddress: aptosAddress ?? this.aptosAddress,
      bitcoinAddress: bitcoinAddress ?? this.bitcoinAddress,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bscAddress': bscAddress,
      'tronAddress': tronAddress,
      'solanaAddress': solanaAddress,
      'suiAddress': suiAddress,
      'aptosAddress': aptosAddress,
      'bitcoinAddress': bitcoinAddress,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    final bscAddress = json['bscAddress'] as String? ?? '';
    final tronAddress = json['tronAddress'] as String? ?? '';
    final solanaAddress = json['solanaAddress'] as String? ?? '';
    final suiAddress = json['suiAddress'] as String? ?? '';
    final aptosAddress = json['aptosAddress'] as String? ?? '';
    final bitcoinAddress = json['bitcoinAddress'] as String? ?? '';
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    return WalletAccount(
      id:
          json['id'] as String? ??
          (bscAddress.isNotEmpty
              ? bscAddress.toLowerCase()
              : tronAddress.isNotEmpty
              ? tronAddress
              : createdAt.toIso8601String()),
      name: json['name'] as String? ?? 'Wallet',
      privateKeyHex: json['privateKeyHex'] as String? ?? '',
      bscAddress: bscAddress,
      tronAddress: tronAddress,
      solanaAddress: solanaAddress,
      suiAddress: suiAddress,
      aptosAddress: aptosAddress,
      bitcoinAddress: bitcoinAddress,
      createdAt: createdAt,
    );
  }
}
