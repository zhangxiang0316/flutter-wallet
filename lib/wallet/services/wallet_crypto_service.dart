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

/// 钱包密钥和地址派生服务。
///
/// 该服务负责：
/// - 生成或导入 12 词英文助记词；
/// - 导入 EVM 私钥；
/// - 从助记词/私钥派生 EVM、TRON、Solana 地址；
/// - 提供基础编码工具，例如 Base58Check、Keccak、HMAC-SHA512。
///
/// 注意：该服务只做本地纯计算，不负责密钥加密存储。私钥/助记词持久化由仓储层
/// 和安全存储相关服务处理。
class WalletCryptoService {
  /// 创建钱包加密服务。
  ///
  /// EVM 和 TRON 地址都基于 secp256k1 曲线，因此初始化时缓存该曲线参数。
  WalletCryptoService() : _domain = ECCurve_secp256k1();

  /// secp256k1 曲线参数。
  final ECDomainParameters _domain;

  /// EVM 默认派生路径。
  ///
  /// 遵循常见 Ethereum 路径 `m/44'/60'/0'/0/0`，BSC、Ethereum、X Layer 共用
  /// 同一 EVM 地址。
  static const String evmDerivationPath = "m/44'/60'/0'/0/0";

  /// Solana 默认派生路径。
  ///
  /// 使用 Solana 常见路径 `m/44'/501'/0'/0'`，并通过 Ed25519 hardened derivation
  /// 派生 seed。
  static const String solanaDerivationPath = "m/44'/501'/0'/0'";

  /// Base58 编码字母表。
  ///
  /// TRON 地址和 Solana 地址都需要 Base58 相关编码。
  static const String _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  /// 生成 12 词英文助记词。
  ///
  /// 返回值是空格分隔的助记词句子，后续可通过 [importMnemonic] 还原钱包地址。
  String generateMnemonic() {
    return Mnemonic.generate(
      Language.english,
      length: MnemonicLength.words12,
    ).sentence;
  }

  /// 导入助记词并派生多链钱包信息。
  ///
  /// 助记词会先标准化和校验，然后生成 BIP39 seed：
  /// - EVM/TRON 使用 secp256k1 私钥；
  /// - Solana 使用 Ed25519 私钥 seed；
  /// - 返回的 [WalletKeyPair] 会保留助记词，便于钱包详情页备份展示。
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

  /// 生成一个随机 EVM 私钥。
  ///
  /// 私钥必须在 `(0, secp256k1.n)` 区间内。返回 64 位小写十六进制字符串，
  /// 不包含 `0x` 前缀。
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

  /// 导入 EVM 私钥并派生多链地址。
  ///
  /// 私钥用于 EVM/TRON secp256k1 地址派生；同时将同一 32 字节输入作为 Solana
  /// Ed25519 seed 生成 Solana 地址。私钥导入没有助记词，因此返回对象的 mnemonic 为 null。
  WalletKeyPair importPrivateKey(String input) {
    final privateKey = normalizePrivateKey(input);
    return _keyPairFromPrivateKeys(
      evmPrivateKeyHex: privateKey,
      solanaPrivateKey: Uint8List.fromList(hex.decode(privateKey)),
    );
  }

  /// 从助记词派生 Solana Ed25519 私钥 seed。
  ///
  /// 转账或签名 Solana 交易时需要该 seed 再生成 Ed25519 keypair。
  Uint8List solanaPrivateKeyFromMnemonic(String input) {
    final mnemonic = normalizeMnemonic(input);
    final seed = Uint8List.fromList(
      Mnemonic.fromSentence(mnemonic, Language.english).seed,
    );
    return _deriveEd25519PrivateKey(seed, solanaDerivationPath);
  }

  /// 从导入的 EVM 私钥得到 Solana Ed25519 seed。
  ///
  /// 该方法保持与 [importPrivateKey] 相同的兼容规则：把 32 字节私钥内容直接作为
  /// Solana seed 使用。
  Uint8List solanaPrivateKeyFromPrivateKey(String input) {
    return Uint8List.fromList(hex.decode(normalizePrivateKey(input)));
  }

  /// 标准化并校验助记词。
  ///
  /// 会去掉首尾空白、压缩多个空白字符、统一转小写，并交给 bip39_mnemonic
  /// 校验词表和 checksum。校验失败会抛出异常。
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

  /// 根据 EVM 私钥和 Solana seed 构造钱包地址集合。
  ///
  /// EVM 地址来自 secp256k1 公钥 Keccak 后 20 字节；TRON 地址使用 `0x41` 前缀
  /// 加 EVM 地址字节再做 Base58Check；Solana 地址来自 Ed25519 公钥 Base58。
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

  /// 标准化并校验 EVM 私钥。
  ///
  /// 支持带或不带 `0x` 前缀。校验内容必须是 32 字节十六进制，并位于 secp256k1
  /// 有效私钥区间内。返回值统一为小写且不带 `0x`。
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

  /// 通过 secp256k1 私钥计算公钥点。
  ECPoint _publicKeyFromPrivateKey(String privateKeyHex) {
    final privateKey = BigInt.parse(privateKeyHex, radix: 16);
    final point = _domain.G * privateKey;
    if (point == null) {
      throw StateError('Failed to derive public key');
    }
    return point;
  }

  /// 从 secp256k1 公钥计算 Ethereum 地址字节。
  ///
  /// Ethereum 地址为未压缩公钥去掉前缀后 Keccak-256 哈希的最后 20 字节。
  Uint8List _ethereumAddressBytes(ECPoint publicKey) {
    final encoded = publicKey.getEncoded(false).sublist(1);
    final digest = KeccakDigest(256)..update(encoded, 0, encoded.length);
    final output = Uint8List(32);
    digest.doFinal(output, 0);
    return Uint8List.fromList(output.sublist(12));
  }

  /// 生成 EIP-55 checksum Ethereum 地址。
  ///
  /// 该格式会按地址小写字符串的 Keccak 哈希决定每个十六进制字母是否大写。
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

  /// Base58Check 编码。
  ///
  /// TRON 地址需要先对 payload 做两次 SHA-256，取前 4 字节作为校验和，再 Base58。
  String _base58CheckEncode(Uint8List payload) {
    final first = _sha256(payload);
    final second = _sha256(first);
    final checksum = second.sublist(0, 4);
    return _base58Encode(Uint8List.fromList([...payload, ...checksum]));
  }

  /// 根据 Ed25519 seed 计算 Solana 地址。
  ///
  /// Solana 地址就是 Ed25519 公钥的 Base58 表示。
  String _solanaAddressFromPrivateKey(Uint8List seed) {
    final privateKey = ed25519.newKeyFromSeed(seed);
    final publicKey = ed25519.public(privateKey);
    return _base58Encode(Uint8List.fromList(publicKey.bytes));
  }

  /// 计算 SHA-256 哈希。
  Uint8List _sha256(Uint8List bytes) {
    final digest = SHA256Digest()..update(bytes, 0, bytes.length);
    final output = Uint8List(32);
    digest.doFinal(output, 0);
    return output;
  }

  /// Base58 编码。
  ///
  /// 编码时需要保留输入开头的 0 字节，它们会转换为 Base58 字母表的第一个字符。
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

  /// 将大端字节数组转为整数。
  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  /// 按 BIP32 规则派生 secp256k1 私钥。
  ///
  /// 该方法用于 EVM 派生路径。hardened 子节点使用 `0x00 + privateKey + index`，
  /// 普通子节点使用压缩公钥加 index。派生出的 child key 必须仍在曲线有效区间。
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

  /// 按 SLIP-0010 风格派生 Ed25519 私钥 seed。
  ///
  /// Ed25519 这里只支持 hardened index，符合 Solana 常用派生路径。
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

  /// 解析派生路径。
  ///
  /// 输入格式必须以 `m` 开头，例如 `m/44'/60'/0'/0/0`。带 `'` 的 index 会加上
  /// hardened 偏移 `0x80000000`。
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

  /// 根据 secp256k1 私钥生成压缩公钥。
  ///
  /// BIP32 非 hardened 子节点派生需要压缩公钥参与 HMAC 输入。
  Uint8List _compressedPublicKey(Uint8List privateKey) {
    final point = _publicKeyFromPrivateKey(hex.encode(privateKey));
    final x = point.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    return Uint8List.fromList([
      y.isEven ? 0x02 : 0x03,
      ..._bigIntToBytes(x, length: 32),
    ]);
  }

  /// 计算 HMAC-SHA512。
  ///
  /// BIP32/SLIP-0010 派生都依赖 HMAC-SHA512 输出的左 32 字节和右 32 字节。
  Uint8List _hmacSha512(Uint8List key, Uint8List data) {
    final hmac = HMac(SHA512Digest(), 128)
      ..init(pc.KeyParameter(key))
      ..update(data, 0, data.length);
    final output = Uint8List(hmac.macSize);
    hmac.doFinal(output, 0);
    return output;
  }

  /// 将 32 位无符号整数转为大端字节。
  Uint8List _uint32Bytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);
  }

  /// 将整数转为固定长度的大端字节。
  ///
  /// 如果整数不足指定长度，会在左侧补 0。
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

/// 派生路径中的单个 index。
///
/// [value] 已经包含 hardened 偏移，调用方可通过 [isHardened] 判断原始语义。
class _DerivationIndex {
  const _DerivationIndex(this.value, {required this.isHardened});

  /// 实际用于 HMAC 输入的 index 值。
  final int value;

  /// 是否是 hardened 子节点。
  final bool isHardened;
}

/// 钱包派生结果。
///
/// 一个钱包在本项目中包含：
/// - 一个 EVM 私钥；
/// - 一个可选助记词；
/// - EVM 地址（BSC/Ethereum/X Layer 共用）；
/// - TRON 地址；
/// - Solana 地址。
class WalletKeyPair {
  const WalletKeyPair({
    required this.privateKeyHex,
    required this.bscAddress,
    required this.tronAddress,
    required this.solanaAddress,
    this.mnemonic,
  });

  /// EVM 私钥，64 位小写十六进制，不带 `0x`。
  final String privateKeyHex;

  /// 可选助记词。
  ///
  /// 通过助记词创建或导入的钱包会保留该字段；私钥导入的钱包没有助记词。
  final String? mnemonic;

  /// EVM 地址，BSC、Ethereum、X Layer 当前共用该地址。
  final String bscAddress;

  /// TRON Base58Check 地址。
  final String tronAddress;

  /// Solana Base58 地址。
  final String solanaAddress;
}
