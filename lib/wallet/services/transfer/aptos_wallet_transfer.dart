part of '../wallet_transfer_service.dart';

extension _AptosWalletTransfer on WalletTransferService {
  Future<TransferFeeEstimate> _estimateAptosFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final client = _aptosClient(asset.chainRef);
    final transaction = await client.transaction.build.simple(
      sender: WalletTransferService.normalizeAptosAddress(asset.address),
      data: _aptosTransferData(asset, toAddress, amount),
    );
    final simulations = await client.transaction.simulate.simple(
      transaction: transaction,
      options: const aptos.InputSimulateTransactionOptions(
        estimateGasUnitPrice: true,
        estimateMaxGasAmount: true,
      ),
    );
    if (simulations.isEmpty || !simulations.first.success) {
      throw StateError(
        simulations.isEmpty
            ? 'Aptos transaction simulation failed'
            : simulations.first.vmStatus,
      );
    }
    final simulation = simulations.first;
    final fee =
        BigInt.parse(simulation.gasUsed) *
        BigInt.parse(simulation.gasUnitPrice);
    return TransferFeeEstimate(
      amount: WalletTransferService.rawUnitsToAmount(fee, 8),
      symbol: 'APT',
      rawAmount: fee,
    );
  }

  Future<String> _transferAptos({
    required List<int> aptosPrivateKey,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final account = _aptosAccountFromSeed(aptosPrivateKey);
    final sender = WalletTransferService.normalizeAptosAddress(asset.address);
    if (account.accountAddress.toString().toLowerCase() != sender) {
      throw StateError('Aptos private key does not match sender address');
    }
    final client = _aptosClient(asset.chainRef);
    final transaction = await client.transaction.build.simple(
      sender: account.accountAddress,
      data: _aptosTransferData(asset, toAddress, amount),
    );
    final simulation = await client.transaction.simulate.simple(
      transaction: transaction,
      signerPublicKey: account.publicKey,
    );
    if (simulation.isEmpty || !simulation.first.success) {
      throw StateError(
        simulation.isEmpty
            ? 'Aptos transaction simulation failed'
            : simulation.first.vmStatus,
      );
    }
    final pending = await client.signAndSubmitTransaction(
      signer: account,
      transaction: transaction,
    );
    return pending.hash;
  }

  aptos.InputEntryFunctionData _aptosTransferData(
    ChainBalance asset,
    String recipient,
    String amount,
  ) {
    final to = WalletTransferService.normalizeAptosAddress(recipient);
    final raw = WalletTransferService.amountToRawUnits(amount, asset.decimals);
    return aptos.InputEntryFunctionData(
      function: asset.isNative
          ? '0x1::aptos_account::transfer'
          : '0x1::primary_fungible_store::transfer',
      typeArguments: asset.isNative
          ? null
          : const ['0x1::fungible_asset::Metadata'],
      functionArguments: asset.isNative
          ? [to, raw]
          : [asset.contractAddress!, to, raw],
      // Built-in framework ABIs are stable. Supplying them locally avoids an
      // extra module-ABI request before every fee estimate and transfer.
      abi: _aptosTransferAbi(asset),
    );
  }

  aptos.EntryFunctionABI _aptosTransferAbi(ChainBalance asset) {
    if (asset.isNative) {
      return aptos.EntryFunctionABI(
        signers: 1,
        typeParameters: const [],
        parameters: [aptos.TypeTagAddress(), aptos.TypeTagU64()],
      );
    }
    return aptos.EntryFunctionABI(
      signers: 1,
      typeParameters: const [
        aptos.MoveFunctionGenericTypeParam(
          constraints: [aptos.MoveAbility.key],
        ),
      ],
      parameters: [
        aptos.parseTypeTag('0x1::object::Object<T0>', allowGenerics: true),
        aptos.TypeTagAddress(),
        aptos.TypeTagU64(),
      ],
    );
  }

  aptos.Account _aptosAccountFromSeed(List<int> seed) {
    if (seed.length != 32) {
      throw const FormatException('Aptos private key must be 32 bytes');
    }
    return aptos.Account.fromPrivateKey(
      privateKey: aptos.Ed25519PrivateKey(Uint8List.fromList(seed), false),
    );
  }

  aptos.Aptos _aptosClient(WalletChainRef chain) => aptos.Aptos(
    aptos.AptosConfig(
      network: aptos.Network.mainnet,
      fullnode: chain.rpcUrl,
      client: aptos.DioClient(_dio),
    ),
  );
}
