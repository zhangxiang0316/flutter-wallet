part of '../wallet_transfer_service.dart';

extension _SolanaWalletTransfer on WalletTransferService {
  Future<TransferFeeEstimate> _estimateSolanaFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    WalletTransferService.normalizeSolanaAddress(toAddress);
    WalletTransferService.amountToRawUnits(amount, asset.decimals);
    final signatureCount = asset.isNative ? 1 : 1;
    return TransferFeeEstimate(
      amount: WalletTransferService.rawUnitsToAmount(
        BigInt.from(
          WalletTransferService._solanaLamportsPerSignature * signatureCount,
        ),
        9,
      ),
      symbol: asset.chainRef.symbol,
      rawAmount: BigInt.from(
        WalletTransferService._solanaLamportsPerSignature * signatureCount,
      ),
      isFallback: true,
    );
  }

  /// 发送 EVM 链交易。
  ///
  /// 原生币交易把金额放在 value；ERC20 交易把 value 设为 0，并把 transfer 调用编码
  /// 放进 data。签名使用 EIP-155 的 chainId 防重放规则。
  Future<String> _transferSolana({
    required List<int> solanaPrivateKey,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final rawAmount = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
    final signer = await Ed25519HDKeyPair.fromPrivateKeyBytes(
      privateKey: solanaPrivateKey,
    );
    if (signer.address !=
        WalletTransferService.normalizeSolanaAddress(asset.address)) {
      throw StateError('Solana private key does not match sender address');
    }

    final recipientPublicKey = Ed25519HDPublicKey.fromBase58(
      WalletTransferService.normalizeSolanaAddress(toAddress),
    );
    final blockhash = await _getLatestSolanaBlockhash(asset.chainRef);
    final message = asset.isNative
        ? _buildSolanaNativeTransferMessage(
            fromPublicKey: signer.publicKey,
            toPublicKey: recipientPublicKey,
            lamports: rawAmount,
          )
        : await _buildSolanaTokenTransferMessage(
            chain: asset.chainRef,
            ownerPublicKey: signer.publicKey,
            recipientPublicKey: recipientPublicKey,
            asset: asset,
            amount: rawAmount,
          );
    final transaction = await signer.signMessage(
      message: message,
      recentBlockhash: blockhash,
    );
    final response = await _solanaRpc(asset.chainRef, 'sendTransaction', [
      transaction.encode(),
      {'encoding': 'base64', 'preflightCommitment': 'confirmed'},
    ]);
    if (response is String && response.isNotEmpty) {
      return response;
    }
    throw StateError('Solana transfer failed');
  }

  /// 创建 TRX 原生转账交易。
  ///
  /// 返回的是节点构造好的未签名交易，后续还需要本地签名和广播。
  Future<dynamic> _solanaRpc(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    final response = await _dio.post(
      chain.rpcUrl,
      data: {'jsonrpc': '2.0', 'method': method, 'params': params, 'id': 1},
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is Map && data['result'] != null) {
      return data['result'];
    }
    throw StateError(data is Map ? data.toString() : 'Invalid Solana response');
  }

  /// 获取 Solana 最新 blockhash。
  ///
  /// Solana 交易必须带 recentBlockhash，过期后交易会被节点拒绝。
  Future<String> _getLatestSolanaBlockhash(WalletChainRef chain) async {
    final result = await _solanaRpc(chain, 'getLatestBlockhash', [
      {'commitment': 'confirmed'},
    ]);
    if (result is Map) {
      final value = result['value'];
      if (value is Map && value['blockhash'] is String) {
        return value['blockhash'] as String;
      }
    }
    throw StateError('Invalid Solana blockhash response');
  }

  /// 读取 TRON 链手续费参数。
  ///
  /// 返回 key 为链参数名，value 为链上整数值。请求失败时返回空 map，由调用方使用默认值。
  Message _buildSolanaNativeTransferMessage({
    required Ed25519HDPublicKey fromPublicKey,
    required Ed25519HDPublicKey toPublicKey,
    required BigInt lamports,
  }) {
    return Message.only(
      SystemInstruction.transfer(
        fundingAccount: fromPublicKey,
        recipientAccount: toPublicKey,
        lamports: WalletTransferService._solanaU64Amount(
          lamports,
          'SOL transfer amount',
        ),
      ),
    );
  }

  /// 构造 SPL Token 转账 message。
  ///
  /// 发送方需要已有该 mint 的 token account；接收方的 ATA 使用 idempotent 创建指令，
  /// 如果已存在不会失败。随后使用 `transferChecked` 携带 decimals 做安全转账。
  Future<Message> _buildSolanaTokenTransferMessage({
    required WalletChainRef chain,
    required Ed25519HDPublicKey ownerPublicKey,
    required Ed25519HDPublicKey recipientPublicKey,
    required ChainBalance asset,
    required BigInt amount,
  }) async {
    final mintAddress = asset.contractAddress;
    if (mintAddress == null || mintAddress.trim().isEmpty) {
      throw StateError('Missing Solana token mint');
    }
    final mintPublicKey = Ed25519HDPublicKey.fromBase58(
      WalletTransferService.normalizeSolanaAddress(mintAddress),
    );
    final sourceTokenAccount = await _findSolanaTokenAccount(
      chain: chain,
      ownerAddress: ownerPublicKey.toBase58(),
      mintAddress: mintPublicKey.toBase58(),
      minimumAmount: amount,
    );
    if (sourceTokenAccount == null) {
      throw StateError('Source Solana token account not found');
    }

    final sourceTokenPublicKey = Ed25519HDPublicKey.fromBase58(
      sourceTokenAccount,
    );
    final destinationTokenPublicKey = await findAssociatedTokenAddress(
      owner: recipientPublicKey,
      mint: mintPublicKey,
    );

    return Message(
      instructions: [
        AssociatedTokenAccountInstruction.createAccountIdempotent(
          funder: ownerPublicKey,
          address: destinationTokenPublicKey,
          owner: recipientPublicKey,
          mint: mintPublicKey,
          tokenProgramId: TokenProgramType.tokenProgram.id,
        ),
        TokenInstruction.transferChecked(
          source: sourceTokenPublicKey,
          mint: mintPublicKey,
          destination: destinationTokenPublicKey,
          owner: ownerPublicKey,
          amount: WalletTransferService._solanaU64Amount(
            amount,
            '${asset.symbol} transfer amount',
          ),
          decimals: asset.decimals,
        ),
      ],
    );
  }

  /// 查找发送方可用的 Solana token account。
  ///
  /// 如果能解析余额，会优先返回余额足够的账户；如果所有账户余额都不足则抛错。
  /// 如果节点没有返回可解析余额，则返回第一个账户作为兜底。
  Future<String?> _findSolanaTokenAccount({
    required WalletChainRef chain,
    required String ownerAddress,
    required String mintAddress,
    required BigInt minimumAmount,
  }) async {
    final data = await _solanaRpc(chain, 'getTokenAccountsByOwner', [
      ownerAddress,
      {'mint': mintAddress},
      {'encoding': 'jsonParsed'},
    ]);
    if (data is! Map) {
      return null;
    }
    final values = data['value'];
    if (values is! List || values.isEmpty) {
      return null;
    }
    String? fallbackAccount;
    var parsedAnyAmount = false;
    for (final item in values) {
      if (item is! Map) continue;
      final pubkey = item['pubkey']?.toString();
      if (pubkey == null || pubkey.isEmpty) continue;
      fallbackAccount ??= pubkey;

      final account = item['account'];
      final accountData = account is Map ? account['data'] : null;
      final parsed = accountData is Map ? accountData['parsed'] : null;
      final info = parsed is Map ? parsed['info'] : null;
      final tokenAmount = info is Map ? info['tokenAmount'] : null;
      final rawAmount = tokenAmount is Map
          ? BigInt.tryParse(tokenAmount['amount']?.toString() ?? '')
          : null;
      if (rawAmount == null) {
        throw StateError(
          'Unable to parse Solana token account balance for address: $pubkey',
        );
      }
      parsedAnyAmount = true;
      if (rawAmount >= minimumAmount) {
        return pubkey;
      }
    }
    if (parsedAnyAmount) {
      throw StateError('Source Solana token account balance is insufficient');
    }
    return fallbackAccount;
  }

  /// 对 32 字节哈希做 secp256k1 ECDSA 签名。
  ///
  /// 签名结果会 normalize 到 low-s，避免高 s 签名在部分节点或工具中被拒绝。
}
