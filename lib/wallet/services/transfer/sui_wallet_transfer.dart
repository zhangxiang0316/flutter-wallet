part of '../wallet_transfer_service.dart';

extension _SuiWalletTransfer on WalletTransferService {
  Future<TransferFeeEstimate> _estimateSuiFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final recipient = WalletTransferService.normalizeSuiAddress(toAddress);
    final rawAmount = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
    final client = _suiClient(asset.chainRef);
    final transaction = _buildSuiTransferTransaction(
      asset: asset,
      recipient: recipient,
      rawAmount: rawAmount,
    );
    final bytes = await client.prepareTransaction(
      transaction,
      sender: WalletTransferService.normalizeSuiAddress(asset.address),
    );
    final simulation = await client.simulateTransaction(
      bytes,
      doGasSelection: false,
    );
    final effects = simulation.transaction.effects;
    if (!effects.status.success) {
      throw StateError(
        effects.status.hasError()
            ? effects.status.error.description
            : 'Sui transaction simulation failed',
      );
    }
    final gas = effects.gasUsed;
    final computation = BigInt.from(gas.computationCost.toInt());
    final storage = BigInt.from(gas.storageCost.toInt());
    final rebate = BigInt.from(gas.storageRebate.toInt());
    final netGas = computation + storage - rebate;
    final safeGas = netGas < BigInt.zero ? BigInt.zero : netGas;
    return TransferFeeEstimate(
      amount: WalletTransferService.rawUnitsToAmount(safeGas, 9),
      symbol: 'SUI',
      rawAmount: safeGas,
    );
  }

  Future<String> _transferSui({
    required List<int> suiPrivateKey,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final recipient = WalletTransferService.normalizeSuiAddress(toAddress);
    final rawAmount = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
    final account = SuiAccount.fromPrivateKey(
      hex.encode(suiPrivateKey),
      SignatureScheme.Ed25519,
    );
    final sender = WalletTransferService.normalizeSuiAddress(asset.address);
    if (account.getAddress().toLowerCase() != sender) {
      throw StateError('Sui private key does not match sender address');
    }

    final result = await _suiClient(asset.chainRef).signAndExecute(
      account,
      _buildSuiTransferTransaction(
        asset: asset,
        recipient: recipient,
        rawAmount: rawAmount,
      ),
    );
    if (!result.success) {
      throw StateError(result.error ?? 'Sui transfer failed');
    }
    return result.digest;
  }

  Transaction _buildSuiTransferTransaction({
    required ChainBalance asset,
    required String recipient,
    required BigInt rawAmount,
  }) {
    final transaction = Transaction();
    final coinType = asset.isNative
        ? '0x2::sui::SUI'
        : asset.contractAddress?.trim();
    if (coinType == null || coinType.isEmpty) {
      throw StateError('Missing Sui coin type');
    }
    final coin = transaction.coin(coinType, rawAmount);
    transaction.transferObjects([coin], transaction.pureAddress(recipient));
    return transaction;
  }

  SuiGrpcClient _suiClient(WalletChainRef chain) {
    return SuiGrpcClient(
      network: SuiNetwork.mainnet,
      dio: _dio,
      endpoint: chain.rpcUrl,
    );
  }
}
