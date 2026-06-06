class WalletAccount {
  const WalletAccount({
    required this.name,
    required this.privateKeyHex,
    required this.bscAddress,
    required this.tronAddress,
    required this.createdAt,
  });

  final String name;
  final String privateKeyHex;
  final String bscAddress;
  final String tronAddress;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'privateKeyHex': privateKeyHex,
      'bscAddress': bscAddress,
      'tronAddress': tronAddress,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    return WalletAccount(
      name: json['name'] as String? ?? 'Wallet',
      privateKeyHex: json['privateKeyHex'] as String? ?? '',
      bscAddress: json['bscAddress'] as String? ?? '',
      tronAddress: json['tronAddress'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
