class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.name,
    required this.privateKeyHex,
    required this.bscAddress,
    required this.tronAddress,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String privateKeyHex;
  final String bscAddress;
  final String tronAddress;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'privateKeyHex': privateKeyHex,
      'bscAddress': bscAddress,
      'tronAddress': tronAddress,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    final bscAddress = json['bscAddress'] as String? ?? '';
    final tronAddress = json['tronAddress'] as String? ?? '';
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
      createdAt: createdAt,
    );
  }
}
