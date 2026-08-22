part of '../wallet_transfer_service.dart';

/// TRON 节点返回交易的签名前校验。
///
/// TRON 的创建交易接口由远端节点返回待签名 `raw_data_hex`。该字段是签名真正覆盖的
/// 字节，因此不能只相信返回 JSON 中便于展示的地址和金额。这里直接解析 protobuf，
/// 并把其中的交易意图与用户确认内容逐项比较。
extension _TronTransactionValidator on WalletTransferService {
  static const int _transferContractType = 1;
  static const int _triggerSmartContractType = 31;
  static const int _maximumTransactionLifetimeMs = 24 * 60 * 60 * 1000;
  static const int _maximumFutureTimestampMs = 5 * 60 * 1000;

  void _validateTronTransactionForSigning({
    required String privateKeyHex,
    required Map<String, dynamic> transaction,
    required ChainBalance asset,
    required String toAddress,
    required BigInt amount,
  }) {
    final signerAddress = WalletCryptoService().tronAddressFromPrivateKey(
      privateKeyHex,
    );
    final expectedOwner = _tronAddressBytes(asset.address);
    final actualSigner = _tronAddressBytes(signerAddress);
    if (!WalletTransferService._bytesEqual(actualSigner, expectedOwner)) {
      throw StateError('TRON signer does not match sender address');
    }

    final rawDataHex = transaction['raw_data_hex']?.toString().trim() ?? '';
    if (rawDataHex.isEmpty) {
      throw StateError('Missing TRON raw data');
    }

    final rawDataBytes = _decodeTronHex(rawDataHex, 'raw_data_hex');
    final expectedTxId = hex.encode(
      WalletTransferService._sha256(rawDataBytes),
    );
    final returnedTxId = transaction['txID']?.toString().trim() ?? '';
    if (returnedTxId.isEmpty) {
      throw StateError('Missing TRON transaction ID');
    }
    if (returnedTxId.toLowerCase() != expectedTxId) {
      throw StateError('TRON transaction ID does not match raw data');
    }

    final rawData = _TronRawData.parse(rawDataBytes);
    _validateTronLifetime(rawData);
    if (rawData.contracts.length != 1) {
      throw StateError('TRON transaction must contain exactly one contract');
    }

    final contract = rawData.contracts.single;
    if (asset.isNative) {
      _validateTronNativeContract(
        contract: contract,
        expectedOwner: expectedOwner,
        expectedRecipient: _tronAddressBytes(toAddress),
        expectedAmount: amount,
      );
      if (rawData.feeLimit != BigInt.zero) {
        throw StateError('Unexpected fee limit for TRON native transfer');
      }
    } else {
      final contractAddress = asset.contractAddress;
      if (contractAddress == null || contractAddress.trim().isEmpty) {
        throw StateError('Missing TRC20 contract address');
      }
      _validateTronTokenContract(
        contract: contract,
        expectedOwner: expectedOwner,
        expectedContract: _tronAddressBytes(contractAddress),
        expectedRecipient: _tronAddressBytes(toAddress),
        expectedAmount: amount,
      );
      if (rawData.feeLimit !=
          BigInt.from(WalletTransferService._tronTokenFeeLimit)) {
        throw StateError('TRC20 fee limit does not match reviewed transaction');
      }
    }

    _validateTronJsonIntent(
      transaction: transaction,
      asset: asset,
      expectedOwner: expectedOwner,
      expectedRecipient: _tronAddressBytes(toAddress),
      expectedAmount: amount,
    );
  }

  void _validateTronLifetime(_TronRawData rawData) {
    final timestamp = rawData.timestamp;
    final expiration = rawData.expiration;
    if (timestamp <= BigInt.zero || expiration <= timestamp) {
      throw StateError('Invalid TRON transaction lifetime');
    }

    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    if (expiration <= now) {
      throw StateError('TRON transaction has expired');
    }
    if (timestamp > now + BigInt.from(_maximumFutureTimestampMs)) {
      throw StateError('TRON transaction timestamp is too far in the future');
    }
    if (expiration - timestamp > BigInt.from(_maximumTransactionLifetimeMs)) {
      throw StateError('TRON transaction lifetime is too long');
    }
  }

  void _validateTronNativeContract({
    required _TronContract contract,
    required Uint8List expectedOwner,
    required Uint8List expectedRecipient,
    required BigInt expectedAmount,
  }) {
    if (contract.type != _transferContractType ||
        !contract.typeUrl.endsWith('protocol.TransferContract')) {
      throw StateError('Unexpected TRON native contract type');
    }
    final transfer = _TronTransferContract.parse(contract.parameter);
    _requireTronBytesEqual(transfer.ownerAddress, expectedOwner, 'sender');
    _requireTronBytesEqual(transfer.toAddress, expectedRecipient, 'recipient');
    if (transfer.amount != expectedAmount) {
      throw StateError('TRON transfer amount does not match reviewed amount');
    }
  }

  void _validateTronTokenContract({
    required _TronContract contract,
    required Uint8List expectedOwner,
    required Uint8List expectedContract,
    required Uint8List expectedRecipient,
    required BigInt expectedAmount,
  }) {
    if (contract.type != _triggerSmartContractType ||
        !contract.typeUrl.endsWith('protocol.TriggerSmartContract')) {
      throw StateError('Unexpected TRC20 contract type');
    }
    final trigger = _TronTriggerSmartContract.parse(contract.parameter);
    _requireTronBytesEqual(trigger.ownerAddress, expectedOwner, 'sender');
    _requireTronBytesEqual(
      trigger.contractAddress,
      expectedContract,
      'token contract',
    );
    if (trigger.callValue != BigInt.zero ||
        trigger.callTokenValue != BigInt.zero ||
        trigger.tokenId != BigInt.zero) {
      throw StateError('Unexpected native or token value in TRC20 transaction');
    }

    final expectedData = _tronTrc20TransferData(
      expectedRecipient,
      expectedAmount,
    );
    _requireTronBytesEqual(trigger.data, expectedData, 'TRC20 call data');
  }

  /// 同时验证广播 JSON 中的交易意图，防止 `raw_data_hex` 与广播时使用的 `raw_data`
  /// 表达不同内容。真正的签名校验仍以 protobuf 字节为准。
  void _validateTronJsonIntent({
    required Map<String, dynamic> transaction,
    required ChainBalance asset,
    required Uint8List expectedOwner,
    required Uint8List expectedRecipient,
    required BigInt expectedAmount,
  }) {
    final rawData = transaction['raw_data'];
    if (rawData is! Map) {
      throw StateError('Missing TRON raw_data JSON');
    }
    final contracts = rawData['contract'];
    if (contracts is! List ||
        contracts.length != 1 ||
        contracts.single is! Map) {
      throw StateError('Invalid TRON raw_data contract list');
    }
    final contract = contracts.single as Map;
    final parameter = contract['parameter'];
    final value = parameter is Map ? parameter['value'] : null;
    if (value is! Map) {
      throw StateError('Missing TRON contract value');
    }

    final expectedType = asset.isNative
        ? 'TransferContract'
        : 'TriggerSmartContract';
    if (contract['type']?.toString() != expectedType) {
      throw StateError(
        'TRON JSON contract type does not match reviewed transfer',
      );
    }
    _requireTronBytesEqual(
      _tronJsonAddress(value['owner_address']),
      expectedOwner,
      'JSON sender',
    );

    if (asset.isNative) {
      _requireTronBytesEqual(
        _tronJsonAddress(value['to_address']),
        expectedRecipient,
        'JSON recipient',
      );
      if (_tronJsonBigInt(value['amount'], 'amount') != expectedAmount) {
        throw StateError('TRON JSON amount does not match reviewed amount');
      }
      return;
    }

    _requireTronBytesEqual(
      _tronJsonAddress(value['contract_address']),
      _tronAddressBytes(asset.contractAddress!),
      'JSON token contract',
    );
    if (_tronJsonBigInt(value['call_value'] ?? 0, 'call_value') !=
        BigInt.zero) {
      throw StateError('Unexpected TRC20 JSON call value');
    }
    final expectedData = _tronTrc20TransferData(
      expectedRecipient,
      expectedAmount,
    );
    _requireTronBytesEqual(
      _decodeTronHex(value['data']?.toString() ?? '', 'TRC20 JSON data'),
      expectedData,
      'JSON TRC20 call data',
    );
    if (_tronJsonBigInt(rawData['fee_limit'], 'fee_limit') !=
        BigInt.from(WalletTransferService._tronTokenFeeLimit)) {
      throw StateError(
        'TRC20 JSON fee limit does not match reviewed transaction',
      );
    }
  }

  Uint8List _tronJsonAddress(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw StateError('Missing TRON address in transaction');
    }
    if (RegExp(r'^(?:0x)?41[0-9a-fA-F]{40}$').hasMatch(text)) {
      return _decodeTronHex(text.replaceFirst(RegExp(r'^0x'), ''), 'address');
    }
    return _tronAddressBytes(text);
  }

  BigInt _tronJsonBigInt(Object? value, String field) {
    final parsed = BigInt.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed < BigInt.zero) {
      throw StateError('Invalid TRON $field');
    }
    return parsed;
  }

  Uint8List _tronAddressBytes(String address) {
    return _decodeTronHex(
      WalletTransferService.tronAddressToHex(address),
      'address',
    );
  }

  Uint8List _tronTrc20TransferData(Uint8List address, BigInt amount) {
    if (address.length != 21 || address.first != 0x41) {
      throw StateError('Invalid TRON address bytes');
    }
    return Uint8List.fromList([
      ..._decodeTronHex('a9059cbb', 'TRC20 method selector'),
      ...List<int>.filled(12, 0),
      ...address.sublist(1),
      ...WalletTransferService._bigIntToBytes(amount, length: 32),
    ]);
  }

  Uint8List _decodeTronHex(String value, String field) {
    final normalized = value.trim().replaceFirst(RegExp(r'^0x'), '');
    if (normalized.isEmpty ||
        normalized.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized)) {
      throw StateError('Invalid TRON $field');
    }
    return Uint8List.fromList(hex.decode(normalized));
  }

  void _requireTronBytesEqual(
    Uint8List actual,
    Uint8List expected,
    String field,
  ) {
    if (!WalletTransferService._bytesEqual(actual, expected)) {
      throw StateError('TRON $field does not match reviewed transaction');
    }
  }
}

class _TronRawData {
  const _TronRawData({
    required this.expiration,
    required this.timestamp,
    required this.feeLimit,
    required this.contracts,
  });

  final BigInt expiration;
  final BigInt timestamp;
  final BigInt feeLimit;
  final List<_TronContract> contracts;

  factory _TronRawData.parse(Uint8List bytes) {
    final fields = _TronProtoReader(bytes).readAll();
    _ensureOnlyTronFields(fields, const {1, 3, 4, 8, 11, 14, 18}, 'raw data');
    return _TronRawData(
      expiration: _requiredTronVarint(fields, 8, 'expiration'),
      timestamp: _requiredTronVarint(fields, 14, 'timestamp'),
      feeLimit: _optionalTronVarint(fields, 18, 'fee_limit'),
      contracts: _tronBytesFields(
        fields,
        11,
        'contract',
      ).map(_TronContract.parse).toList(growable: false),
    );
  }
}

class _TronContract {
  const _TronContract({
    required this.type,
    required this.typeUrl,
    required this.parameter,
  });

  final int type;
  final String typeUrl;
  final Uint8List parameter;

  factory _TronContract.parse(Uint8List bytes) {
    final fields = _TronProtoReader(bytes).readAll();
    _ensureOnlyTronFields(fields, const {1, 2}, 'contract');
    final anyFields = _TronProtoReader(
      _requiredTronBytes(fields, 2, 'contract parameter'),
    ).readAll();
    _ensureOnlyTronFields(anyFields, const {1, 2}, 'contract parameter');
    return _TronContract(
      type: _requiredTronVarint(fields, 1, 'contract type').toInt(),
      typeUrl: utf8.decode(
        _requiredTronBytes(anyFields, 1, 'contract type URL'),
      ),
      parameter: _requiredTronBytes(anyFields, 2, 'contract value'),
    );
  }
}

class _TronTransferContract {
  const _TronTransferContract({
    required this.ownerAddress,
    required this.toAddress,
    required this.amount,
  });

  final Uint8List ownerAddress;
  final Uint8List toAddress;
  final BigInt amount;

  factory _TronTransferContract.parse(Uint8List bytes) {
    final fields = _TronProtoReader(bytes).readAll();
    _ensureOnlyTronFields(fields, const {1, 2, 3}, 'transfer contract');
    return _TronTransferContract(
      ownerAddress: _requiredTronBytes(fields, 1, 'owner_address'),
      toAddress: _requiredTronBytes(fields, 2, 'to_address'),
      amount: _requiredTronVarint(fields, 3, 'amount'),
    );
  }
}

class _TronTriggerSmartContract {
  const _TronTriggerSmartContract({
    required this.ownerAddress,
    required this.contractAddress,
    required this.callValue,
    required this.data,
    required this.callTokenValue,
    required this.tokenId,
  });

  final Uint8List ownerAddress;
  final Uint8List contractAddress;
  final BigInt callValue;
  final Uint8List data;
  final BigInt callTokenValue;
  final BigInt tokenId;

  factory _TronTriggerSmartContract.parse(Uint8List bytes) {
    final fields = _TronProtoReader(bytes).readAll();
    _ensureOnlyTronFields(fields, const {
      1,
      2,
      3,
      4,
      5,
      6,
    }, 'trigger smart contract');
    return _TronTriggerSmartContract(
      ownerAddress: _requiredTronBytes(fields, 1, 'owner_address'),
      contractAddress: _requiredTronBytes(fields, 2, 'contract_address'),
      callValue: _optionalTronVarint(fields, 3, 'call_value'),
      data: _requiredTronBytes(fields, 4, 'data'),
      callTokenValue: _optionalTronVarint(fields, 5, 'call_token_value'),
      tokenId: _optionalTronVarint(fields, 6, 'token_id'),
    );
  }
}

class _TronProtoField {
  const _TronProtoField({
    required this.number,
    required this.wireType,
    this.varint,
    this.bytes,
  });

  final int number;
  final int wireType;
  final BigInt? varint;
  final Uint8List? bytes;
}

class _TronProtoReader {
  _TronProtoReader(this.bytes);

  final Uint8List bytes;
  int _offset = 0;

  List<_TronProtoField> readAll() {
    final fields = <_TronProtoField>[];
    while (_offset < bytes.length) {
      final key = _readVarint();
      if (key <= BigInt.zero || key > BigInt.from(0x7fffffff)) {
        throw StateError('Invalid TRON protobuf field key');
      }
      final keyValue = key.toInt();
      final fieldNumber = keyValue >> 3;
      final wireType = keyValue & 7;
      if (fieldNumber == 0) {
        throw StateError('Invalid TRON protobuf field number');
      }
      switch (wireType) {
        case 0:
          fields.add(
            _TronProtoField(
              number: fieldNumber,
              wireType: wireType,
              varint: _readVarint(),
            ),
          );
        case 1:
          _skip(8);
        case 2:
          final length = _readVarint();
          if (length < BigInt.zero || length > BigInt.from(bytes.length)) {
            throw StateError('Invalid TRON protobuf field length');
          }
          final value = _readBytes(length.toInt());
          fields.add(
            _TronProtoField(
              number: fieldNumber,
              wireType: wireType,
              bytes: value,
            ),
          );
        case 5:
          _skip(4);
        default:
          throw StateError('Unsupported TRON protobuf wire type');
      }
    }
    return fields;
  }

  BigInt _readVarint() {
    var result = BigInt.zero;
    var shift = 0;
    for (var index = 0; index < 10; index++) {
      if (_offset >= bytes.length) {
        throw StateError('Truncated TRON protobuf varint');
      }
      final byte = bytes[_offset++];
      result |= BigInt.from(byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
    }
    throw StateError('TRON protobuf varint is too long');
  }

  Uint8List _readBytes(int length) {
    if (length < 0 || _offset + length > bytes.length) {
      throw StateError('Truncated TRON protobuf field');
    }
    final value = Uint8List.fromList(bytes.sublist(_offset, _offset + length));
    _offset += length;
    return value;
  }

  void _skip(int length) {
    _readBytes(length);
  }
}

BigInt _requiredTronVarint(
  List<_TronProtoField> fields,
  int number,
  String name,
) {
  final matching = fields.where((field) => field.number == number).toList();
  if (matching.length != 1 || matching.single.wireType != 0) {
    throw StateError('Missing or duplicated TRON $name');
  }
  return matching.single.varint!;
}

BigInt _optionalTronVarint(
  List<_TronProtoField> fields,
  int number,
  String name,
) {
  final matching = fields.where((field) => field.number == number).toList();
  if (matching.isEmpty) return BigInt.zero;
  if (matching.length != 1 || matching.single.wireType != 0) {
    throw StateError('Duplicated or invalid TRON $name');
  }
  return matching.single.varint!;
}

Uint8List _requiredTronBytes(
  List<_TronProtoField> fields,
  int number,
  String name,
) {
  final matching = _tronBytesFields(fields, number, name);
  if (matching.length != 1) {
    throw StateError('Missing or duplicated TRON $name');
  }
  return matching.single;
}

List<Uint8List> _tronBytesFields(
  List<_TronProtoField> fields,
  int number,
  String name,
) {
  final matching = fields.where((field) => field.number == number).toList();
  if (matching.any((field) => field.wireType != 2 || field.bytes == null)) {
    throw StateError('Invalid TRON $name');
  }
  return matching.map((field) => field.bytes!).toList(growable: false);
}

void _ensureOnlyTronFields(
  List<_TronProtoField> fields,
  Set<int> allowed,
  String scope,
) {
  if (fields.any((field) => !allowed.contains(field.number))) {
    throw StateError('Unexpected TRON protobuf field in $scope');
  }
}
