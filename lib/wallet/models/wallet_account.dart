/// Stable address namespaces persisted with a wallet.
///
/// These strings deliberately do not use `WalletChainType`. A newly registered
/// chain can introduce another namespace without changing the wallet model.
abstract final class WalletAddressNamespace {
  static const evm = 'evm';
  static const tron = 'tron';
  static const solana = 'solana';
  static const bitcoin = 'bitcoin';
  static const sui = 'sui';
  static const aptos = 'aptos';
}

class WalletAccount {
  WalletAccount({
    required this.id,
    required this.name,
    required this.createdAt,
    Map<String, String> addressesByNamespace = const {},
    String bscAddress = '',
    String tronAddress = '',
    String solanaAddress = '',
    String suiAddress = '',
    String aptosAddress = '',
    String bitcoinAddress = '',
    this.privateKeyHex = '',
  }) : addressesByNamespace = Map<String, String>.unmodifiable(
         _mergeAddresses(
           addressesByNamespace: addressesByNamespace,
           bscAddress: bscAddress,
           tronAddress: tronAddress,
           solanaAddress: solanaAddress,
           suiAddress: suiAddress,
           aptosAddress: aptosAddress,
           bitcoinAddress: bitcoinAddress,
         ),
       );

  final String id;
  final String name;

  /// Only populated for legacy wallets that were saved before secure storage.
  final String privateKeyHex;

  /// Chain addresses keyed by adapter-owned namespace.
  final Map<String, String> addressesByNamespace;

  final DateTime createdAt;

  /// Compatibility getters for call sites that have not yet moved to a
  /// namespace lookup. New code should use [addressForNamespace].
  String get bscAddress => addressForNamespace(WalletAddressNamespace.evm);
  String get tronAddress => addressForNamespace(WalletAddressNamespace.tron);
  String get solanaAddress =>
      addressForNamespace(WalletAddressNamespace.solana);
  String get suiAddress => addressForNamespace(WalletAddressNamespace.sui);
  String get aptosAddress => addressForNamespace(WalletAddressNamespace.aptos);
  String get bitcoinAddress =>
      addressForNamespace(WalletAddressNamespace.bitcoin);

  String addressForNamespace(String namespace) {
    return addressesByNamespace[namespace]?.trim() ?? '';
  }

  bool get needsSecretMigration => privateKeyHex.isNotEmpty;

  WalletAccount copyWith({
    String? id,
    String? name,
    String? privateKeyHex,
    Map<String, String>? addressesByNamespace,
    String? bscAddress,
    String? tronAddress,
    String? solanaAddress,
    String? suiAddress,
    String? aptosAddress,
    String? bitcoinAddress,
    DateTime? createdAt,
  }) {
    final nextAddresses = <String, String>{
      ...(addressesByNamespace ?? this.addressesByNamespace),
    };
    void replace(String namespace, String? address) {
      if (address == null) return;
      final value = address.trim();
      if (value.isEmpty) {
        nextAddresses.remove(namespace);
      } else {
        nextAddresses[namespace] = value;
      }
    }

    replace(WalletAddressNamespace.evm, bscAddress);
    replace(WalletAddressNamespace.tron, tronAddress);
    replace(WalletAddressNamespace.solana, solanaAddress);
    replace(WalletAddressNamespace.sui, suiAddress);
    replace(WalletAddressNamespace.aptos, aptosAddress);
    replace(WalletAddressNamespace.bitcoin, bitcoinAddress);
    return WalletAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      privateKeyHex: privateKeyHex ?? this.privateKeyHex,
      addressesByNamespace: nextAddresses,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'addressesByNamespace': addressesByNamespace,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    final persistedAddresses = <String, String>{};
    final rawAddresses = json['addressesByNamespace'];
    if (rawAddresses is Map) {
      for (final entry in rawAddresses.entries) {
        final namespace = entry.key.toString().trim();
        final address = entry.value?.toString().trim() ?? '';
        if (namespace.isNotEmpty && address.isNotEmpty) {
          persistedAddresses[namespace] = address;
        }
      }
    }
    final bscAddress = json['bscAddress'] as String? ?? '';
    final tronAddress = json['tronAddress'] as String? ?? '';
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    final addresses = _mergeAddresses(
      addressesByNamespace: persistedAddresses,
      bscAddress: bscAddress,
      tronAddress: tronAddress,
      solanaAddress: json['solanaAddress'] as String? ?? '',
      suiAddress: json['suiAddress'] as String? ?? '',
      aptosAddress: json['aptosAddress'] as String? ?? '',
      bitcoinAddress: json['bitcoinAddress'] as String? ?? '',
    );
    final evmAddress = addresses[WalletAddressNamespace.evm] ?? '';
    final tron = addresses[WalletAddressNamespace.tron] ?? '';
    return WalletAccount(
      id:
          json['id'] as String? ??
          (evmAddress.isNotEmpty
              ? evmAddress.toLowerCase()
              : tron.isNotEmpty
              ? tron
              : createdAt.toIso8601String()),
      name: json['name'] as String? ?? 'Wallet',
      privateKeyHex: json['privateKeyHex'] as String? ?? '',
      addressesByNamespace: addresses,
      createdAt: createdAt,
    );
  }

  static Map<String, String> _mergeAddresses({
    required Map<String, String> addressesByNamespace,
    required String bscAddress,
    required String tronAddress,
    required String solanaAddress,
    required String suiAddress,
    required String aptosAddress,
    required String bitcoinAddress,
  }) {
    final result = <String, String>{};
    void add(String namespace, String address) {
      final key = namespace.trim();
      final value = address.trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        result.putIfAbsent(key, () => value);
      }
    }

    add(WalletAddressNamespace.evm, bscAddress);
    add(WalletAddressNamespace.tron, tronAddress);
    add(WalletAddressNamespace.solana, solanaAddress);
    add(WalletAddressNamespace.sui, suiAddress);
    add(WalletAddressNamespace.aptos, aptosAddress);
    add(WalletAddressNamespace.bitcoin, bitcoinAddress);
    for (final entry in addressesByNamespace.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isNotEmpty && value.isNotEmpty) result[key] = value;
    }
    return result;
  }
}
