/// 钱包地址簿条目。
class WalletAddressBookEntry {
  const WalletAddressBookEntry({
    required this.id,
    required this.name,
    required this.address,
    required this.chainId,
    required this.chainName,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String address;
  final String chainId;
  final String chainName;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  WalletAddressBookEntry copyWith({
    String? id,
    String? name,
    String? address,
    String? chainId,
    String? chainName,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletAddressBookEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      chainId: chainId ?? this.chainId,
      chainName: chainName ?? this.chainName,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'chainId': chainId,
      'chainName': chainName,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory WalletAddressBookEntry.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return WalletAddressBookEntry(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      chainId: json['chainId']?.toString() ?? '',
      chainName: json['chainName']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
    );
  }
}
