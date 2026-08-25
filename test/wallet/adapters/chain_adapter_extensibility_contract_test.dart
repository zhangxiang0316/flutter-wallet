import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/transfer/controller/transfer_scan_address_parser.dart';
import 'package:omnicast/wallet/adapters/chain_adapter.dart';
import 'package:omnicast/wallet/adapters/chain_adapter_registry.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/models/wallet_key_material.dart';
import 'package:omnicast/wallet/models/wallet_transaction_record.dart';
import 'package:omnicast/wallet/services/chain_balance_service.dart';
import 'package:omnicast/wallet/services/crypto/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/config/wallet_custom_asset_service.dart';
import 'package:omnicast/wallet/services/transaction/wallet_transaction_status_service.dart';
import 'package:omnicast/wallet/services/wallet_transaction_history_service.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';
import 'package:omnicast/wallet/services/wallet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a new adapter resolves an address without wallet model changes', () {
    final registry = ChainAdapterRegistry([_testAdapter]);
    final wallet = WalletAccount(
      id: 'wallet-test',
      name: 'Test Wallet',
      addressesByNamespace: const {_testNamespace: _testAddress},
      createdAt: DateTime.utc(2026, 8, 25),
    );

    expect(registry.require(_testChain).id, _testAdapterId);
    expect(
      WalletChainConfig.fromJson(_testChain.toJson()).adapterId,
      _testAdapterId,
    );
    expect(
      registry
          .require(_testChain)
          .walletAddress(ChainWalletAddresses.fromWallet(wallet)),
      _testAddress,
    );
    expect(
      WalletAccount.fromJson(
        wallet.toJson(),
      ).addressForNamespace(_testNamespace),
      _testAddress,
    );
  });

  test('payment URI support comes from the registered adapter', () {
    final request = TransferScanAddressParser.parse(
      'testcoin:$_testAddress?amount=1',
      _testChain,
      adapterRegistry: ChainAdapterRegistry([_testAdapter]),
    );

    expect(request?.chainId, _testChain.id);
    expect(request?.address, _testAddress);
  });

  test('custom asset validation comes from the registered adapter', () {
    final asset = WalletCustomAssetService(
      adapterRegistry: ChainAdapterRegistry([_testAdapter]),
    ).buildManualAsset(
      chain: _testChain,
      contractAddress: ' test-token-id ',
      symbol: 'tst',
      name: 'Test Token',
      decimals: 6,
    );

    expect(asset.contractAddress, 'test-token-id');
    expect(asset.symbol, 'TST');
  });

  test('key material readers are selected by adapter namespace', () async {
    final repository = WalletRepository(
      keyMaterialReaders: {
        _testNamespace: ({required walletId, required password}) async =>
            const WalletKeyMaterial(
              privateKeyHex: 'test-private-key',
              signingKeyBytes: [1, 2, 3],
            ),
      },
    );

    final material = await repository.readWalletKeyMaterial(
      namespace: _testAdapter.keyMaterialNamespace,
      walletId: 'wallet-test',
      password: 'password',
    );

    expect(material.privateKeyHex, 'test-private-key');
    expect(material.signingKeyBytes, [1, 2, 3]);
  });

  test('a derivation adapter adds an account without WalletKeyPair fields', () {
    final crypto = WalletCryptoService(
      accountDerivers: [
        WalletAccountDerivationAdapter(
          namespace: _testNamespace,
          fromMnemonic: (_) => const DerivedAccount(address: _testAddress),
          fromPrivateKey: (_) => const DerivedAccount(address: _testAddress),
        ),
      ],
    );

    final keyPair = crypto.importPrivateKey(
      '0000000000000000000000000000000000000000000000000000000000000001',
    );

    expect(keyPair.addressForNamespace(_testNamespace), _testAddress);
  });

  test(
    'a new adapter injects every chain operation without type routing',
    () async {
      final registry = ChainAdapterRegistry([_testAdapter]);
      var balanceCalls = 0;
      final balanceService = ChainBalanceService(
        adapterRegistry: registry,
        balanceLoaders: {
          _testAdapterId:
              ({
                required chain,
                required address,
                required assets,
                required customAssets,
              }) async {
                balanceCalls++;
                return [_asset];
              },
        },
      );
      final transferService = WalletTransferService(
        adapterRegistry: registry,
        transferOperations: {
          _testAdapterId: (request) async => 'test-transaction-hash',
        },
        feeEstimators: {
          _testAdapterId:
              ({required asset, required toAddress, required amount}) async =>
                  TransferFeeEstimate(
                    amount: '0.1',
                    symbol: _testChain.symbol,
                    rawAmount: BigInt.one,
                  ),
        },
      );
      final historyService = WalletTransactionHistoryService(
        adapterRegistry: registry,
        historyPageLoaders: {
          _testAdapterId:
              ({required walletId, required asset, required cursor}) async =>
                  const TransactionHistoryPageResult(
                    records: [],
                    nextCursor: null,
                  ),
        },
      );
      final statusService = WalletTransactionStatusService(
        adapterRegistry: registry,
        statusLoaders: {
          _testAdapterId: (_, _) async => WalletTransactionStatus.success,
        },
      );

      expect(
        await balanceService.loadChainBalances(
          chain: _testChain,
          address: _testAddress,
        ),
        [_asset],
      );
      expect(balanceCalls, 1);
      expect(
        await transferService.estimateFee(
          asset: _asset,
          toAddress: _testAddress,
          amount: '1',
        ),
        isA<TransferFeeEstimate>(),
      );
      expect(
        await transferService.transfer(
          privateKeyHex: '11',
          asset: _asset,
          toAddress: _testAddress,
          amount: '1',
        ),
        'test-transaction-hash',
      );
      expect(
        (await historyService.loadAssetRecordPage(
          walletId: 'wallet-test',
          asset: _asset,
        )).records,
        isEmpty,
      );
      expect(
        await statusService.loadStatus(
          chain: _testChain,
          txHash: 'test-transaction-hash',
        ),
        WalletTransactionStatus.success,
      );
    },
  );
}

const _testAdapterId = 'test-chain';
const _testNamespace = 'test-account';
const _testAddress = 'test1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq';

const _testChain = WalletChainConfig(
  id: 'test-chain-mainnet',
  name: 'Test Chain',
  symbol: 'TST',
  rpcUrls: ['https://rpc.test.invalid'],
  type: WalletChainType.solana,
  adapterId: _testAdapterId,
);

const _asset = ChainBalance.config(
  chainConfig: _testChain,
  symbol: 'TST',
  name: 'Test Token',
  amount: '1',
  address: _testAddress,
  decimals: 6,
);

final _testAdapter = RegisteredChainAdapter(
  id: _testAdapterId,
  type: WalletChainType.solana,
  addressNamespace: _testNamespace,
  keyMaterialNamespace: _testNamespace,
  paymentUriSchemes: const {'testcoin'},
  capabilities: const ChainCapabilities({
    ChainCapability.walletAddressResolution,
    ChainCapability.addressValidation,
    ChainCapability.balance,
    ChainCapability.transfer,
    ChainCapability.feeEstimation,
    ChainCapability.history,
    ChainCapability.transactionStatus,
    ChainCapability.receive,
    ChainCapability.customAssets,
    ChainCapability.paymentUri,
  }),
  addressNormalizer: (input) => input.trim(),
  addressExtractor: (input) => input.startsWith('test1') ? input : null,
  addressExplorerBuilder: (_, _) => null,
  transactionExplorerBuilder: (_, _) => null,
);
