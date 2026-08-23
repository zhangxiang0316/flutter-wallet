import 'dart:convert';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';

import 'web_wallet_crypto.dart' as web_crypto;

/// 钱包密钥存储异常基类。
class WalletSecretException implements Exception {
  const WalletSecretException(this.message);

  /// 面向调用方展示或记录的错误信息。
  final String message;

  @override
  String toString() => message;
}

/// 钱包密钥不存在。
class WalletSecretMissingException extends WalletSecretException {
  const WalletSecretMissingException() : super('Wallet private key is missing');
}

/// 密码错误或密文损坏。
class WalletSecretInvalidPasswordException extends WalletSecretException {
  const WalletSecretInvalidPasswordException()
    : super('Wallet password is invalid');
}

/// 存储数据损坏。
class WalletSecretCorruptedException extends WalletSecretException {
  const WalletSecretCorruptedException(super.message);
}

/// 钱包私钥和助记词加密存储。
///
/// 该服务使用 `flutter_secure_storage` 保存密文 payload。明文私钥/助记词不会直接写入
/// storage；保存时会通过 PBKDF2-HMAC-SHA256 从用户密码派生 AES-256 密钥，再用
/// AES-GCM 加密。
///
/// 当前 payload 结构包含 version、kdf、iterations、salt、nonce、cipherText，便于
/// 后续升级 KDF 或加密参数。
class WalletSecretStore {
  /// 创建密钥存储服务。
  ///
  /// Android 使用 encryptedSharedPreferences；iOS 使用 first_unlock_this_device，
  /// 使设备重启首次解锁后可访问钱包密钥。
  WalletSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            // macOS ad-hoc/local builds do not have the provisioning
            // entitlements required by the Data Protection Keychain.
            // Use the regular login keychain so first-run wallet creation
            // also works before Developer ID signing is configured.
            mOptions: MacOsOptions(useDataProtectionKeyChain: false),
          );

  /// 平台安全存储。
  final FlutterSecureStorage _storage;

  /// PBKDF2 默认迭代次数。
  static const int _iterations = 100000;

  /// AES-256 密钥长度。
  static const int _keyBytes = 32;

  /// AES-GCM nonce 长度，推荐 12 字节。
  static const int _nonceBytes = 12;

  /// 加密保存钱包私钥。
  Future<void> savePrivateKey({
    required String walletId,
    required String password,
    required String privateKeyHex,
  }) async {
    return _saveEncryptedText(
      key: _secretKey(walletId),
      password: password,
      value: privateKeyHex,
    );
  }

  /// 加密保存钱包助记词。
  ///
  /// 私钥导入的钱包可能没有助记词，此方法只在创建钱包或助记词导入时调用。
  Future<void> saveMnemonic({
    required String walletId,
    required String password,
    required String mnemonic,
  }) {
    return _saveEncryptedText(
      key: _mnemonicKey(walletId),
      password: password,
      value: mnemonic,
    );
  }

  /// 加密保存任意文本密钥。
  ///
  /// 每次保存都会生成新的 salt 和 nonce。同一密码在不同钱包、不同保存时间下派生出的
  /// 实际加密密钥也不同。
  Future<void> _saveEncryptedText({
    required String key,
    required String password,
    required String value,
  }) async {
    // WebCrypto runs PBKDF2/AES-GCM in the browser's asynchronous crypto
    // implementation, so the Web build does not spend 100k iterations on the
    // Flutter UI isolate. Native platforms continue to use compute/isolate.
    final webPayload = await web_crypto.encryptPayload(password, value);
    final payloadText =
        webPayload ??
        await compute(_encryptPayload, <String>[
          password,
          value,
        ], debugLabel: 'encrypt-wallet-secret');

    await _storage.write(key: key, value: payloadText);
  }

  /// 通过 Flutter 跨平台计算任务生成 PBKDF2 和 AES-GCM payload。
  ///
  /// Android/iOS 使用后台 isolate，Web 使用 Flutter 的兼容回退。参数只包含可传递的
  /// 字符串，不会把平台安全存储对象带入计算任务。
  static String _encryptPayload(List<String> values) {
    final password = values[0];
    final value = values[1];
    final salt = _randomBytes(32);
    final nonce = _randomBytes(_nonceBytes);
    final encryptionKey = _deriveKey(password, salt);
    final plainBytes = utf8.encode(value);
    final cipherText = _aesGcmEncrypt(encryptionKey, nonce, plainBytes);

    return jsonEncode({
      'version': 1,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _iterations,
      'salt': hex.encode(salt),
      'nonce': hex.encode(nonce),
      'cipherText': hex.encode(cipherText),
    });
  }

  /// 读取并解密钱包私钥。
  ///
  /// 如果新格式密钥不存在，会尝试读取旧版本拆分存储的密文私钥，方便旧数据迁移。
  Future<String> readPrivateKey({
    required String walletId,
    required String password,
  }) async {
    return _readEncryptedText(
      key: _secretKey(walletId),
      password: password,
      onMissing: () => _readLegacyEncryptedPrivateKey(
        walletId: walletId,
        password: password,
      ),
    );
  }

  /// 读取并解密钱包助记词。
  Future<String> readMnemonic({
    required String walletId,
    required String password,
  }) {
    return _readEncryptedText(key: _mnemonicKey(walletId), password: password);
  }

  /// 读取密文 payload 并解密为明文字符串。
  ///
  /// 解密失败统一转换成 [WalletSecretInvalidPasswordException]。这里不区分密码错误、
  /// 密文损坏或字段格式异常，避免向 UI 暴露过多内部细节。
  Future<String> _readEncryptedText({
    required String key,
    required String password,
    Future<String> Function()? onMissing,
  }) async {
    final payloadText = await _storage.read(key: key);
    if (payloadText == null || payloadText.isEmpty) {
      if (onMissing != null) {
        return onMissing();
      }
      throw const WalletSecretMissingException();
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
      final webPlainText = await web_crypto.decryptPayload(
        password: password,
        salt: salt,
        nonce: nonce,
        cipherText: cipherText,
        iterations: iterations,
      );
      if (webPlainText != null) return webPlainText;
      final key = _deriveKey(password, salt, iterations: iterations);
      final plainBytes = _aesGcmDecrypt(key, nonce, cipherText);
      return utf8.decode(plainBytes);
    } on FormatException catch (e) {
      throw WalletSecretCorruptedException(
        'Storage data corrupted: ${e.message}',
      );
    } catch (_) {
      throw const WalletSecretInvalidPasswordException();
    }
  }

  /// 读取旧版本拆分字段保存的私钥密文。
  ///
  /// 旧格式分别保存 salt、nonce、cipher 三个 key。读取成功后由仓储迁移流程重新保存
  /// 为当前 JSON payload 格式。
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
      final webPlainText = await web_crypto.decryptPayload(
        password: password,
        salt: salt,
        nonce: nonce,
        cipherText: cipherText,
        iterations: _iterations,
      );
      if (webPlainText != null) return webPlainText;
      final key = _deriveKey(password, salt);
      final plainBytes = _aesGcmDecrypt(key, nonce, cipherText);
      return utf8.decode(plainBytes);
    } catch (_) {
      throw const WalletSecretInvalidPasswordException();
    }
  }

  /// 删除钱包的所有敏感数据。
  ///
  /// 同时删除当前格式的私钥/助记词和旧格式字段，确保移除钱包后不残留敏感信息。
  Future<void> removePrivateKey(String walletId) async {
    await _storage.delete(key: _secretKey(walletId));
    await _storage.delete(key: _mnemonicKey(walletId));
    await _storage.delete(key: 'w_$walletId:salt');
    await _storage.delete(key: 'w_$walletId:nonce');
    await _storage.delete(key: 'w_$walletId:cipher');
  }

  /// 判断钱包是否存在私钥。
  ///
  /// 兼容当前 JSON payload 和旧格式 cipher 字段。
  Future<bool> hasPrivateKey(String walletId) async {
    if (await _storage.containsKey(key: _secretKey(walletId))) {
      return true;
    }
    return _storage.containsKey(key: 'w_$walletId:cipher');
  }

  /// 判断钱包是否存在助记词。
  Future<bool> hasMnemonic(String walletId) {
    return _storage.containsKey(key: _mnemonicKey(walletId));
  }

  /// 将旧版本明文私钥迁移为加密私钥。
  ///
  /// 该方法只负责写入 secure storage；清理普通存储中的明文字段由 [WalletRepository]
  /// 在迁移流程中完成。
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

  /// 使用 PBKDF2-HMAC-SHA256 从用户密码派生 AES 密钥。
  ///
  /// [iterations] 从 payload 读取，便于未来提高迭代次数时仍能解密旧数据。
  static Uint8List _deriveKey(
    String password,
    Uint8List salt, {
    int iterations = _iterations,
  }) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(salt, iterations, _keyBytes));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// 使用 AES-GCM 加密明文。
  ///
  /// 返回值包含密文和认证标签，pointycastle 的 GCMBlockCipher 会把 tag 拼在末尾。
  static Uint8List _aesGcmEncrypt(
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

  /// 使用 AES-GCM 解密密文。
  ///
  /// 如果密码错误或认证标签不匹配，底层会抛异常，调用方统一转换为密码错误异常。
  static Uint8List _aesGcmDecrypt(
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

  /// 生成加密用随机字节。
  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  /// 生成私钥存储 key。
  ///
  /// walletId 先做 base64Url，避免特殊字符影响底层 key 命名。
  String _secretKey(String walletId) {
    return 'wallet_secret_${base64Url.encode(utf8.encode(walletId))}';
  }

  /// 生成助记词存储 key。
  String _mnemonicKey(String walletId) {
    return 'wallet_mnemonic_${base64Url.encode(utf8.encode(walletId))}';
  }
}
