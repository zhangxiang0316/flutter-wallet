import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:pointycastle/digests/keccak.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';

class WalletCryptoService {
  WalletCryptoService() : _domain = ECCurve_secp256k1();

  final ECDomainParameters _domain;
  static const String _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

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
    final publicKey = _publicKeyFromPrivateKey(privateKey);
    final ethAddressBytes = _ethereumAddressBytes(publicKey);
    final bscAddress = '0x${hex.encode(ethAddressBytes)}';
    final tronPayload = Uint8List.fromList([0x41, ...ethAddressBytes]);

    return WalletKeyPair(
      privateKeyHex: privateKey,
      bscAddress: _toChecksumEthereumAddress(bscAddress),
      tronAddress: _base58CheckEncode(tronPayload),
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
}

class WalletKeyPair {
  const WalletKeyPair({
    required this.privateKeyHex,
    required this.bscAddress,
    required this.tronAddress,
  });

  final String privateKeyHex;
  final String bscAddress;
  final String tronAddress;
}
