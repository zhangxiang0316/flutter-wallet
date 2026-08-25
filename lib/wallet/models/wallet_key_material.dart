/// Short-lived signing material selected by a chain adapter.
///
/// The value must never be persisted or logged. [privateKeyHex] supports
/// secp256k1 implementations; [signingKeyBytes] supports Ed25519 chains.
class WalletKeyMaterial {
  const WalletKeyMaterial({required this.privateKeyHex, this.signingKeyBytes});

  final String privateKeyHex;
  final List<int>? signingKeyBytes;
}

typedef WalletKeyMaterialReader =
    Future<WalletKeyMaterial> Function({
      required String walletId,
      required String password,
    });
