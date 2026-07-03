part of '../wallet_transfer_service.dart';

extension WalletTransferMessageSigning on WalletTransferService {
  // ========== 消息签名方法（Phase 2 新增）==========

  /// EIP-191 personal_sign 签名
  ///
  /// 对消息添加 Ethereum 前缀后签名：
  /// "\x19Ethereum Signed Message:\n" + len(message) + message
  ///
  /// 返回十六进制签名字符串（带 0x 前缀）
  Future<String> signPersonalMessage({
    required String message,
    required String privateKeyHex,
  }) async {
    // 1. 构造带前缀的消息
    final messageBytes = _isHexString(message)
        ? WalletTransferService.hexToBytes(message)
        : Uint8List.fromList(message.codeUnits);

    final prefix = '\x19Ethereum Signed Message:\n${messageBytes.length}';
    final prefixBytes = Uint8List.fromList(prefix.codeUnits);

    final fullMessage = Uint8List.fromList([...prefixBytes, ...messageBytes]);

    // 2. Keccak-256 哈希
    final hash = WalletTransferService._keccak(fullMessage);

    // 3. 使用 secp256k1 签名
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);

    // 4. 组装签名：r + s + v
    final rBytes = WalletTransferService._bigIntToBytes(
      signature.r,
      length: 32,
    );
    final sBytes = WalletTransferService._bigIntToBytes(
      signature.s,
      length: 32,
    );

    // 5. 返回十六进制签名
    return '0x${hex.encode([...rBytes, ...sBytes, recoveryId])}';
  }

  /// EIP-712 typed data 签名
  ///
  /// 对结构化数据进行签名，用于更复杂的授权场景。
  /// typedData 格式参考 EIP-712 规范。
  ///
  /// 返回十六进制签名字符串（带 0x 前缀）
  Future<String> signTypedData({
    required Map<String, dynamic> typedData,
    required String privateKeyHex,
  }) async {
    // 1. 计算 EIP-712 domain separator
    final domainSeparator = _hashStruct(
      typedData['domain'] as Map<String, dynamic>,
      typedData['types'] as Map<String, dynamic>,
      'EIP712Domain',
    );

    // 2. 计算消息哈希
    final messageHash = _hashStruct(
      typedData['message'] as Map<String, dynamic>,
      typedData['types'] as Map<String, dynamic>,
      typedData['primaryType'] as String,
    );

    // 3. 构造 EIP-712 签名数据
    // "\x19\x01" + domainSeparator + messageHash
    final signData = Uint8List.fromList([
      0x19,
      0x01,
      ...domainSeparator,
      ...messageHash,
    ]);

    // 4. Keccak-256 哈希
    final hash = WalletTransferService._keccak(signData);

    // 5. 使用 secp256k1 签名
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);

    // 6. 组装签名
    final rBytes = WalletTransferService._bigIntToBytes(
      signature.r,
      length: 32,
    );
    final sBytes = WalletTransferService._bigIntToBytes(
      signature.s,
      length: 32,
    );

    // 7. 返回十六进制签名
    return '0x${hex.encode([...rBytes, ...sBytes, recoveryId])}';
  }

  /// Solana 消息签名
  ///
  /// 使用 Ed25519 签名原始消息或 UTF-8 文本。
  ///
  /// 返回 Base58 编码的签名字符串
  Future<String> signSolanaMessage({
    required String message,
    required Uint8List privateKeySeed,
  }) async {
    // 1. 将消息转为字节
    final messageBytes = _isHexString(message)
        ? WalletTransferService.hexToBytes(message)
        : Uint8List.fromList(message.codeUnits);

    // 2. 从 seed 生成 Ed25519 keypair
    final keypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(
      privateKey: privateKeySeed,
    );

    // 3. 签名消息
    final signature = await keypair.sign(messageBytes);

    // 4. 返回 Base58 编码的签名
    return signature.toBase58();
  }

  /// TRON 消息签名
  ///
  /// 使用与 TRON 交易相同的 secp256k1 签名，
  /// 但对原始消息进行 SHA-256 哈希（而非交易的 raw_data）。
  ///
  /// 返回十六进制签名字符串（带 0x 前缀）
  Future<String> signTronMessage({
    required String message,
    required String privateKeyHex,
  }) async {
    // 1. 添加 TRON 消息前缀
    final messageBytes = _isHexString(message)
        ? WalletTransferService.hexToBytes(message)
        : Uint8List.fromList(message.codeUnits);

    final prefix = '\x19TRON Signed Message:\n${messageBytes.length}';
    final prefixBytes = Uint8List.fromList(prefix.codeUnits);

    final fullMessage = Uint8List.fromList([...prefixBytes, ...messageBytes]);

    // 2. SHA-256 哈希（TRON 使用 SHA-256，不是 Keccak-256）
    final digest = SHA256Digest();
    final hash = digest.process(fullMessage);

    // 3. 使用 secp256k1 签名
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);

    // 4. 组装签名
    final rBytes = WalletTransferService._bigIntToBytes(
      signature.r,
      length: 32,
    );
    final sBytes = WalletTransferService._bigIntToBytes(
      signature.s,
      length: 32,
    );

    // 5. 返回十六进制签名
    return '0x${hex.encode([...rBytes, ...sBytes, recoveryId])}';
  }

  // ========== EIP-712 辅助方法 ==========

  /// 判断字符串是否为十六进制格式
  bool _isHexString(String value) {
    return value.startsWith('0x') || RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);
  }

  /// EIP-712 结构体哈希
  Uint8List _hashStruct(
    Map<String, dynamic> data,
    Map<String, dynamic> types,
    String typeName,
  ) {
    // 获取类型定义
    final type = types[typeName] as List<dynamic>;

    // 1. 计算 typeHash
    final encodeType = _encodeType(typeName, types);
    final typeHash = WalletTransferService._keccak(
      Uint8List.fromList(encodeType.codeUnits),
    );

    // 2. 编码每个字段
    final encodedValues = <int>[...typeHash];
    for (final field in type) {
      final fieldName = field['name'] as String;
      final fieldType = field['type'] as String;
      final fieldValue = data[fieldName];

      encodedValues.addAll(_encodeValue(fieldType, fieldValue, types));
    }

    // 3. Keccak-256 哈希
    return WalletTransferService._keccak(Uint8List.fromList(encodedValues));
  }

  /// EIP-712 类型编码
  String _encodeType(String typeName, Map<String, dynamic> types) {
    final type = types[typeName] as List<dynamic>;
    final fields = type.map((f) => '${f['type']} ${f['name']}').join(',');
    return '$typeName($fields)';
  }

  /// EIP-712 值编码
  Uint8List _encodeValue(
    String type,
    dynamic value,
    Map<String, dynamic> types,
  ) {
    // 基础类型
    if (type == 'address') {
      final addr = (value as String).replaceFirst('0x', '').padLeft(64, '0');
      return WalletTransferService.hexToBytes('0x$addr');
    }
    if (type == 'string') {
      return WalletTransferService._keccak(
        Uint8List.fromList((value as String).codeUnits),
      );
    }
    if (type == 'bytes') {
      return WalletTransferService._keccak(
        WalletTransferService.hexToBytes(value as String),
      );
    }
    if (type.startsWith('uint') || type.startsWith('int')) {
      final numValue = BigInt.parse(value.toString());
      return WalletTransferService._bigIntToBytes(numValue, length: 32);
    }
    if (type == 'bool') {
      return WalletTransferService._bigIntToBytes(
        value == true ? BigInt.one : BigInt.zero,
        length: 32,
      );
    }

    // 自定义结构体
    if (types.containsKey(type)) {
      return _hashStruct(value as Map<String, dynamic>, types, type);
    }

    // 数组类型
    if (type.endsWith('[]')) {
      final itemType = type.substring(0, type.length - 2);
      final items = (value as List)
          .map((item) => _encodeValue(itemType, item, types))
          .toList();
      final concatenated = items.expand((x) => x).toList();
      return WalletTransferService._keccak(Uint8List.fromList(concatenated));
    }

    throw ArgumentError('Unsupported type: $type');
  }
}
