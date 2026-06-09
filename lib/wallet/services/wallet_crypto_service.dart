import 'dart:math';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:convert/convert.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;
import 'package:pointycastle/digests/keccak.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/digests/sha512.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/api.dart' as pc;

class WalletCryptoService {
  WalletCryptoService() : _domain = ECCurve_secp256k1();

  final ECDomainParameters _domain;
  static const String evmDerivationPath = "m/44'/60'/0'/0/0";
  static const String solanaDerivationPath = "m/44'/501'/0'/0'";
  static const String _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  String generateMnemonic() {
    return Mnemonic.generate(
      Language.english,
      length: MnemonicLength.words12,
    ).sentence;
  }

  WalletKeyPair importMnemonic(String input) {
    final mnemonic = normalizeMnemonic(input);
    final seed = Uint8List.fromList(
      Mnemonic.fromSentence(mnemonic, Language.english).seed,
    );
    final evmPrivateKey = _deriveSecp256k1PrivateKey(seed, evmDerivationPath);
    final solanaPrivateKey = _deriveEd25519PrivateKey(
      seed,
      solanaDerivationPath,
    );
    return _keyPairFromPrivateKeys(
      evmPrivateKeyHex: hex.encode(evmPrivateKey),
      solanaPrivateKey: solanaPrivateKey,
      mnemonic: mnemonic,
    );
  }

  String generatePrivateKeyHex() {
    final random = Random.secure();
    BigInt value;
    do {
      final bytes = Uint8List.fromList(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      value = _bytesToBigInt(bytes);
    } while (value == BigInt.zero || value >= _domain.n);

    return value.toRadixString(16).padLeft(64, '0');
  }

  WalletKeyPair importPrivateKey(String input) {
    final privateKey = normalizePrivateKey(input);
    return _keyPairFromPrivateKeys(
      evmPrivateKeyHex: privateKey,
      solanaPrivateKey: Uint8List.fromList(hex.decode(privateKey)),
    );
  }

  String normalizeMnemonic(String input) {
    final value = input
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .join(' ');
    Mnemonic.fromSentence(value, Language.english);
    return value;
  }

  WalletKeyPair _keyPairFromPrivateKeys({
    required String evmPrivateKeyHex,
    required Uint8List solanaPrivateKey,
    String? mnemonic,
  }) {
    final privateKey = normalizePrivateKey(evmPrivateKeyHex);
    final publicKey = _publicKeyFromPrivateKey(privateKey);
    final ethAddressBytes = _ethereumAddressBytes(publicKey);
    final bscAddress = '0x${hex.encode(ethAddressBytes)}';
    final tronPayload = Uint8List.fromList([0x41, ...ethAddressBytes]);
    final solanaAddress = _solanaAddressFromPrivateKey(solanaPrivateKey);

    return WalletKeyPair(
      privateKeyHex: privateKey,
      mnemonic: mnemonic,
      bscAddress: _toChecksumEthereumAddress(bscAddress),
      tronAddress: _base58CheckEncode(tronPayload),
      solanaAddress: solanaAddress,
    );
  }

  String normalizePrivateKey(String input) {
    final value = input.trim().replaceFirst(RegExp('^0x'), '');
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value)) {
      throw const FormatException('Invalid private key');
    }

    final key = BigInt.parse(value, radix: 16);
    if (key == BigInt.zero || key >= _domain.n) {
      throw const FormatException('Private key is out of range');
    }

    return value.toLowerCase();
  }

  ECPoint _publicKeyFromPrivateKey(String privateKeyHex) {
    final privateKey = BigInt.parse(privateKeyHex, radix: 16);
    final point = _domain.G * privateKey;
    if (point == null) {
      throw StateError('Failed to derive public key');
    }
    return point;
  }

  Uint8List _ethereumAddressBytes(ECPoint publicKey) {
    final encoded = publicKey.getEncoded(false).sublist(1);
    final digest = KeccakDigest(256)..update(encoded, 0, encoded.length);
    final output = Uint8List(32);
    digest.doFinal(output, 0);
    return Uint8List.fromList(output.sublist(12));
  }

  String _toChecksumEthereumAddress(String address) {
    final lower = address.replaceFirst('0x', '').toLowerCase();
    final input = Uint8List.fromList(lower.codeUnits);
    final digest = KeccakDigest(256)..update(input, 0, input.length);
    final output = Uint8List(32);
    digest.doFinal(output, 0);
    final hash = hex.encode(output);

    final buffer = StringBuffer('0x');
    for (var i = 0; i < lower.length; i++) {
      final hashNibble = int.parse(hash[i], radix: 16);
      buffer.write(hashNibble >= 8 ? lower[i].toUpperCase() : lower[i]);
    }
    return buffer.toString();
  }

  String _base58CheckEncode(Uint8List payload) {
    final first = _sha256(payload);
    final second = _sha256(first);
    final checksum = second.sublist(0, 4);
    return _base58Encode(Uint8List.fromList([...payload, ...checksum]));
  }

  String _solanaAddressFromPrivateKey(Uint8List seed) {
    final privateKey = ed25519.newKeyFromSeed(seed);
    final publicKey = ed25519.public(privateKey);
    return _base58Encode(Uint8List.fromList(publicKey.bytes));
  }

  Uint8List _sha256(Uint8List bytes) {
    final digest = SHA256Digest()..update(bytes, 0, bytes.length);
    final output = Uint8List(32);
    digest.doFinal(output, 0);
    return output;
  }

  String _base58Encode(Uint8List bytes) {
    var value = _bytesToBigInt(bytes);
    final result = StringBuffer();
    while (value > BigInt.zero) {
      final mod = value % BigInt.from(58);
      value = value ~/ BigInt.from(58);
      result.write(_base58Alphabet[mod.toInt()]);
    }

    for (final byte in bytes) {
      if (byte == 0) {
        result.write(_base58Alphabet[0]);
      } else {
        break;
      }
    }

    return result.toString().split('').reversed.join();
  }

  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  Uint8List _deriveSecp256k1PrivateKey(Uint8List seed, String path) {
    var node = _hmacSha512(Uint8List.fromList('Bitcoin seed'.codeUnits), seed);
    var privateKey = Uint8List.fromList(node.sublist(0, 32));
    var chainCode = Uint8List.fromList(node.sublist(32));

    for (final index in _parseDerivationPath(path)) {
      final publicKey = _compressedPublicKey(privateKey);
      final data = index.isHardened
          ? Uint8List.fromList([0, ...privateKey, ..._uint32Bytes(index.value)])
          : Uint8List.fromList([...publicKey, ..._uint32Bytes(index.value)]);
      node = _hmacSha512(chainCode, data);
      final left = _bytesToBigInt(Uint8List.fromList(node.sublist(0, 32)));
      final parent = _bytesToBigInt(privateKey);
      final child = (left + parent) % _domain.n;
      if (left >= _domain.n || child == BigInt.zero) {
        throw StateError('Invalid BIP32 child key');
      }
      privateKey = _bigIntToBytes(child, length: 32);
      chainCode = Uint8List.fromList(node.sublist(32));
    }
    return privateKey;
  }

  Uint8List _deriveEd25519PrivateKey(Uint8List seed, String path) {
    var node = _hmacSha512(Uint8List.fromList('ed25519 seed'.codeUnits), seed);
    var privateKey = Uint8List.fromList(node.sublist(0, 32));
    var chainCode = Uint8List.fromList(node.sublist(32));

    for (final index in _parseDerivationPath(path)) {
      if (!index.isHardened) {
        throw StateError('Ed25519 derivation requires hardened indexes');
      }
      node = _hmacSha512(
        chainCode,
        Uint8List.fromList([0, ...privateKey, ..._uint32Bytes(index.value)]),
      );
      privateKey = Uint8List.fromList(node.sublist(0, 32));
      chainCode = Uint8List.fromList(node.sublist(32));
    }
    return privateKey;
  }

  List<_DerivationIndex> _parseDerivationPath(String path) {
    final parts = path.split('/');
    if (parts.isEmpty || parts.first != 'm') {
      throw const FormatException('Invalid derivation path');
    }
    return parts
        .skip(1)
        .map((part) {
          final hardened = part.endsWith("'");
          final valueText = hardened
              ? part.substring(0, part.length - 1)
              : part;
          final value = int.tryParse(valueText);
          if (value == null || value < 0 || value >= 0x80000000) {
            throw const FormatException('Invalid derivation path index');
          }
          return _DerivationIndex(
            hardened ? value + 0x80000000 : value,
            isHardened: hardened,
          );
        })
        .toList(growable: false);
  }

  Uint8List _compressedPublicKey(Uint8List privateKey) {
    final point = _publicKeyFromPrivateKey(hex.encode(privateKey));
    final x = point.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    return Uint8List.fromList([
      y.isEven ? 0x02 : 0x03,
      ..._bigIntToBytes(x, length: 32),
    ]);
  }

  Uint8List _hmacSha512(Uint8List key, Uint8List data) {
    final hmac = HMac(SHA512Digest(), 128)
      ..init(pc.KeyParameter(key))
      ..update(data, 0, data.length);
    final output = Uint8List(hmac.macSize);
    hmac.doFinal(output, 0);
    return output;
  }

  Uint8List _uint32Bytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);
  }

  Uint8List _bigIntToBytes(BigInt value, {int length = 32}) {
    final result = Uint8List(length);
    var remaining = value;
    for (var i = length - 1; i >= 0; i--) {
      result[i] = (remaining & BigInt.from(0xff)).toInt();
      remaining >>= 8;
    }
    return result;
  }
}

class _DerivationIndex {
  const _DerivationIndex(this.value, {required this.isHardened});

  final int value;
  final bool isHardened;
}

class WalletKeyPair {
  const WalletKeyPair({
    required this.privateKeyHex,
    required this.bscAddress,
    required this.tronAddress,
    required this.solanaAddress,
    this.mnemonic,
  });

  final String privateKeyHex;
  final String? mnemonic;
  final String bscAddress;
  final String tronAddress;
  final String solanaAddress;
}
