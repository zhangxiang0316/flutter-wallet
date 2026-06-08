import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';

class WalletSecretException implements Exception {
  const WalletSecretException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WalletSecretMissingException extends WalletSecretException {
  const WalletSecretMissingException() : super('Wallet private key is missing');
}

class WalletSecretInvalidPasswordException extends WalletSecretException {
  const WalletSecretInvalidPasswordException()
    : super('Wallet password is invalid');
}

class WalletSecretStore {
  WalletSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;
  static const int _iterations = 100000;
  static const int _keyBytes = 32;
  static const int _nonceBytes = 12;

  Future<void> savePrivateKey({
    required String walletId,
    required String password,
    required String privateKeyHex,
  }) async {
    final salt = _randomBytes(32);
    final nonce = _randomBytes(_nonceBytes);
    final key = _deriveKey(password, salt);
    final plainBytes = utf8.encode(privateKeyHex);
    final cipherText = _aesGcmEncrypt(key, nonce, plainBytes);

    await _storage.write(
      key: _secretKey(walletId),
      value: jsonEncode({
        'version': 1,
        'kdf': 'pbkdf2-hmac-sha256',
        'iterations': _iterations,
        'salt': hex.encode(salt),
        'nonce': hex.encode(nonce),
        'cipherText': hex.encode(cipherText),
      }),
    );
  }

  Future<String> readPrivateKey({
    required String walletId,
    required String password,
  }) async {
    final payloadText = await _storage.read(key: _secretKey(walletId));
    if (payloadText == null || payloadText.isEmpty) {
      return _readLegacyEncryptedPrivateKey(
        walletId: walletId,
        password: password,
      );
    }

    try {
      final payload = jsonDecode(payloadText);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Invalid wallet secret payload');
      }
      final iterations = payload['iterations'] as int? ?? _iterations;
      final salt = Uint8List.fromList(hex.decode(payload['salt'] as String));
      final nonce = Uint8List.fromList(hex.decode(payload['nonce'] as String));
      final cipherText = Uint8List.fromList(
        hex.decode(payload['cipherText'] as String),
      );
      final key = _deriveKey(password, salt, iterations: iterations);
      final plainBytes = _aesGcmDecrypt(key, nonce, cipherText);
      return utf8.decode(plainBytes);
    } catch (_) {
      throw const WalletSecretInvalidPasswordException();
    }
  }

  Future<String> _readLegacyEncryptedPrivateKey({
    required String walletId,
    required String password,
  }) async {
    final saltHex = await _storage.read(key: 'w_$walletId:salt');
    final nonceHex = await _storage.read(key: 'w_$walletId:nonce');
    final cipherHex = await _storage.read(key: 'w_$walletId:cipher');
    if (saltHex == null || nonceHex == null || cipherHex == null) {
      throw const WalletSecretMissingException();
    }
    try {
      final salt = Uint8List.fromList(hex.decode(saltHex));
      final nonce = Uint8List.fromList(hex.decode(nonceHex));
      final cipherText = Uint8List.fromList(hex.decode(cipherHex));
      final key = _deriveKey(password, salt);
      final plainBytes = _aesGcmDecrypt(key, nonce, cipherText);
      return utf8.decode(plainBytes);
    } catch (_) {
      throw const WalletSecretInvalidPasswordException();
    }
  }

  Future<void> removePrivateKey(String walletId) async {
    await _storage.delete(key: _secretKey(walletId));
    await _storage.delete(key: 'w_$walletId:salt');
    await _storage.delete(key: 'w_$walletId:nonce');
    await _storage.delete(key: 'w_$walletId:cipher');
  }

  Future<bool> hasPrivateKey(String walletId) async {
    if (await _storage.containsKey(key: _secretKey(walletId))) {
      return true;
    }
    return _storage.containsKey(key: 'w_$walletId:cipher');
  }

  Future<void> migratePlainSecret({
    required String walletId,
    required String password,
    required String privateKeyHex,
  }) {
    return savePrivateKey(
      walletId: walletId,
      password: password,
      privateKeyHex: privateKeyHex,
    );
  }

  Uint8List _deriveKey(
    String password,
    Uint8List salt, {
    int iterations = _iterations,
  }) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(salt, iterations, _keyBytes));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List _aesGcmEncrypt(
    Uint8List key,
    Uint8List nonce,
    List<int> plainText,
  ) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = pc.AEADParameters(
      pc.KeyParameter(key),
      128,
      nonce,
      Uint8List(0),
    );
    cipher.init(true, params);
    return cipher.process(Uint8List.fromList(plainText));
  }

  Uint8List _aesGcmDecrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List cipherText,
  ) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = pc.AEADParameters(
      pc.KeyParameter(key),
      128,
      nonce,
      Uint8List(0),
    );
    cipher.init(false, params);
    return cipher.process(cipherText);
  }

  Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  String _secretKey(String walletId) {
    return 'wallet_secret_${base64Url.encode(utf8.encode(walletId))}';
  }
}
