import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/crypto/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';
import '../test_support/fallback_rpc_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletTransferService', () {
    test('converts decimal amounts to raw units', () {
      expect(
        WalletTransferService.amountToRawUnits('1.25', 18).toString(),
        '1250000000000000000',
      );
      expect(
        WalletTransferService.amountToRawUnits('0.000001', 6).toString(),
        '1',
      );
      expect(
        () => WalletTransferService.amountToRawUnits('0.0000001', 6),
        throwsFormatException,
      );
    });

    test('formats raw fee units for display', () {
      expect(
        WalletTransferService.rawUnitsToAmount(
          BigInt.from(21000) * BigInt.from(3000000000),
          18,
        ),
        '0.000063',
      );
      expect(
        WalletTransferService.rawUnitsToAmount(BigInt.from(30000000), 6),
        '30',
      );
    });

    test('encodes ERC20 transfer data', () {
      expect(
        WalletTransferService.erc20TransferData(
          '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
          BigInt.from(1000000),
        ),
        '0xa9059cbb0000000000000000000000007e5f4552091a69125d5dfcb7b8c2659029395bdf00000000000000000000000000000000000000000000000000000000000f4240',
      );
    });

    test('defines Ethereum, X Layer, Arbitrum, and Base as EVM chains', () {
      expect(WalletChain.ethereum.evmChainId, 1);
      expect(WalletChain.ethereum.symbol, 'ETH');
      expect(WalletChain.xLayer.evmChainId, 196);
      expect(WalletChain.xLayer.symbol, 'OKB');
      expect(WalletChain.arbitrum.evmChainId, 42161);
      expect(WalletChain.arbitrum.symbol, 'ETH');
      expect(WalletChain.base.evmChainId, 8453);
      expect(WalletChain.base.symbol, 'ETH');
      expect(WalletChain.solana.evmChainId, isNull);
      expect(WalletChain.solana.symbol, 'SOL');
      expect(
        WalletTransferService.normalizeBscAddress(
          '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        ),
        '0x7e5f4552091a69125d5dfcb7b8c2659029395bdf',
      );
    });

    test('adds Base L1 fee and falls back across RPC nodes', () async {
      final adapter = _BaseTransferAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final transferService = WalletTransferService(dio: dio);
      final keyPair = WalletCryptoService().importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );
      final asset = ChainBalance(
        chain: WalletChain.base,
        symbol: 'ETH',
        name: 'Ethereum',
        amount: '1',
        address: keyPair.bscAddress,
        decimals: 18,
      );

      final estimate = await transferService.estimateFee(
        asset: asset,
        toAddress: '0x2222222222222222222222222222222222222222',
        amount: '0.1',
      );
      final hash = await transferService.transfer(
        privateKeyHex: keyPair.privateKeyHex,
        asset: asset,
        toAddress: '0x2222222222222222222222222222222222222222',
        amount: '0.1',
      );

      expect(estimate.rawAmount, BigInt.from(21001000000000));
      expect(estimate.amount, '0.00002100');
      expect(estimate.isFallback, isFalse);
      expect(hash, '0xbasehash');
      expect(adapter.mainnetMethods, contains('eth_gasPrice'));
      expect(adapter.fallbackMethods, contains('eth_call'));
      expect(adapter.fallbackMethods, contains('eth_sendRawTransaction'));
      expect(adapter.lastOracleCallData, startsWith('0x'));
      expect(adapter.lastOracleCallData, hasLength(74));
    });

    test('encodes TRC20 transfer parameters', () {
      expect(
        WalletTransferService.trc20TransferParameter(
          'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
          BigInt.from(1000000),
        ),
        '0000000000000000000000007e5f4552091a69125d5dfcb7b8c2659029395bdf00000000000000000000000000000000000000000000000000000000000f4240',
      );
    });

    test('submits native Solana transfer through RPC', () async {
      final adapter = FallbackRpcAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final transferService = WalletTransferService(dio: dio);
      final cryptoService = WalletCryptoService();
      final keyPair = cryptoService.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );
      final hash = await transferService.transfer(
        privateKeyHex: keyPair.privateKeyHex,
        solanaPrivateKey: cryptoService.solanaPrivateKeyFromPrivateKey(
          keyPair.privateKeyHex,
        ),
        asset: ChainBalance(
          chain: WalletChain.solana,
          symbol: 'SOL',
          name: 'Solana',
          amount: '1',
          address: keyPair.solanaAddress,
          decimals: 9,
        ),
        toAddress: '11111111111111111111111111111111',
        amount: '0.001',
      );

      expect(hash, 'solana-signature');
      expect(adapter.solanaMethods, contains('getLatestBlockhash'));
      expect(adapter.solanaMethods, contains('sendTransaction'));
      expect(adapter.lastSolanaTransactionBase64, isNotEmpty);
      expect(
        base64Decode(adapter.lastSolanaTransactionBase64!).length,
        greaterThan(100),
      );
    });

    test('builds and simulates Aptos APT and USDC transfers', () async {
      final cryptoService = WalletCryptoService();
      final keyPair = cryptoService.importMnemonic(
        'abandon abandon abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon about',
      );
      final adapter = _AptosTransferAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final transferService = WalletTransferService(dio: dio);
      final aptAsset = ChainBalance(
        chain: WalletChain.aptos,
        symbol: 'APT',
        name: 'Aptos',
        amount: '2',
        address: keyPair.aptosAddress,
        decimals: 8,
      );
      final usdcAsset = ChainBalance(
        chain: WalletChain.aptos,
        symbol: 'USDC',
        name: 'USD Coin',
        amount: '2',
        address: keyPair.aptosAddress,
        contractAddress:
            '0xbae207659db88bea0cbead6da0ed00aac12edcdda169e591cd41c94180b46f3b',
        decimals: 6,
      );

      final aptFee = await transferService.estimateFee(
        asset: aptAsset,
        toAddress: '0x2',
        amount: '1',
      );
      final usdcFee = await transferService.estimateFee(
        asset: usdcAsset,
        toAddress: '0x2',
        amount: '1',
      );

      expect(aptFee.amount, '0.00001');
      expect(usdcFee.amount, '0.00001');
      expect(aptFee.symbol, 'APT');
      expect(adapter.simulateCount, 2);
      expect(adapter.moduleAbiRequestCount, 0);
    });

    test('submits SPL token transfer through RPC', () async {
      final cryptoService = WalletCryptoService();
      final keyPair = cryptoService.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );
      final sourceTokenAccount = cryptoService
          .importPrivateKey(
            '0x0000000000000000000000000000000000000000000000000000000000000002',
          )
          .solanaAddress;
      final recipient = cryptoService
          .importPrivateKey(
            '0x0000000000000000000000000000000000000000000000000000000000000003',
          )
          .solanaAddress;
      final adapter = FallbackRpcAdapter(
        solanaTokenAccountPubkey: sourceTokenAccount,
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final transferService = WalletTransferService(dio: dio);

      final hash = await transferService.transfer(
        privateKeyHex: keyPair.privateKeyHex,
        solanaPrivateKey: cryptoService.solanaPrivateKeyFromPrivateKey(
          keyPair.privateKeyHex,
        ),
        asset: ChainBalance(
          chain: WalletChain.solana,
          symbol: 'USDC',
          name: 'USD Coin',
          amount: '10',
          address: keyPair.solanaAddress,
          contractAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          decimals: 6,
        ),
        toAddress: recipient,
        amount: '1.25',
      );

      expect(hash, 'solana-signature');
      expect(adapter.solanaMethods, contains('getTokenAccountsByOwner'));
      expect(adapter.solanaMethods, contains('getLatestBlockhash'));
      expect(adapter.solanaMethods, contains('sendTransaction'));
      expect(adapter.lastSolanaTransactionBase64, isNotEmpty);
      expect(
        base64Decode(adapter.lastSolanaTransactionBase64!).length,
        greaterThan(180),
      );
    });

    test(
      'rejects SPL token transfer when source balance is insufficient',
      () async {
        final cryptoService = WalletCryptoService();
        final keyPair = cryptoService.importPrivateKey(
          '0x0000000000000000000000000000000000000000000000000000000000000001',
        );
        final sourceTokenAccount = cryptoService
            .importPrivateKey(
              '0x0000000000000000000000000000000000000000000000000000000000000002',
            )
            .solanaAddress;
        final recipient = cryptoService
            .importPrivateKey(
              '0x0000000000000000000000000000000000000000000000000000000000000003',
            )
            .solanaAddress;
        final adapter = FallbackRpcAdapter(
          solanaTokenAccountsByOwner: [
            {
              'pubkey': sourceTokenAccount,
              'account': {
                'data': {
                  'parsed': {
                    'info': {
                      'tokenAmount': {'amount': '1000000', 'decimals': 6},
                    },
                  },
                },
              },
            },
          ],
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final transferService = WalletTransferService(dio: dio);

        expect(
          () => transferService.transfer(
            privateKeyHex: keyPair.privateKeyHex,
            solanaPrivateKey: cryptoService.solanaPrivateKeyFromPrivateKey(
              keyPair.privateKeyHex,
            ),
            asset: ChainBalance(
              chain: WalletChain.solana,
              symbol: 'USDC',
              name: 'USD Coin',
              amount: '10',
              address: keyPair.solanaAddress,
              contractAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
              decimals: 6,
            ),
            toAddress: recipient,
            amount: '1.25',
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('insufficient'),
            ),
          ),
        );
      },
    );

    test('estimates and submits native Bitcoin P2WPKH transfer', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about';
      final cryptoService = WalletCryptoService();
      final keyPair = cryptoService.importMnemonic(mnemonic);
      final bitcoinPrivateKey = cryptoService.bitcoinPrivateKeyFromMnemonic(
        mnemonic,
      );
      final adapter = FallbackRpcAdapter(
        bitcoinFeeRate: 5,
        bitcoinUtxoSats: 100000000,
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final transferService = WalletTransferService(dio: dio);
      final asset = ChainBalance(
        chain: WalletChain.bitcoin,
        symbol: 'BTC',
        name: 'Bitcoin',
        amount: '1',
        address: keyPair.bitcoinAddress,
        decimals: 8,
        canonicalTokenId: 'btc',
      );

      final estimate = await transferService.estimateFee(
        asset: asset,
        toAddress: keyPair.bitcoinAddress,
        amount: '0.1',
      );
      final hash = await transferService.transfer(
        privateKeyHex: bitcoinPrivateKey,
        asset: asset,
        toAddress: keyPair.bitcoinAddress,
        amount: '0.1',
      );

      expect(estimate.rawAmount, BigInt.from(710));
      expect(estimate.amount, '0.0000071');
      expect(estimate.isFallback, isFalse);
      expect(hash, List.filled(64, 'a').join());
      expect(adapter.bitcoinBroadcastCount, 1);
      expect(adapter.lastBitcoinRawTransaction, startsWith('020000000001'));
      expect(adapter.lastBitcoinRawTransaction, isNotEmpty);

      final raw = adapter.lastBitcoinRawTransaction!;
      expect(
        raw,
        '0200000000010101000000000000000000000000000000000000000000000000'
        '000000000000000000000000ffffffff028096980000000000160014c0cebcd6'
        'c3d3ca8c75dc5ec62ebe55330ef910e2ba475d0500000000160014c0cebcd6c3'
        'd3ca8c75dc5ec62ebe55330ef910e202483045022100b1acb0848f9dafa7ab85'
        '8a52478a488a8de91403ddd3a654dd1fc716be74b600022016f734ab8f17cc05'
        '44a0032a141cf917b186b1a13a4a3e1bc554cc39d4d3aea401210330d54fd0dd'
        '420a6e5f8d3624f5f3482cae350f79d5f0753bf5beef9c2d91af3c00000000',
      );
      expect(raw.substring(96, 98), '02');
      final sent = _littleEndianHexToInt(raw.substring(98, 114));
      final change = _littleEndianHexToInt(raw.substring(160, 176));
      expect(sent, BigInt.from(10000000));
      expect(BigInt.from(100000000) - sent - change, estimate.rawAmount);
    });

    test('rejects Bitcoin dust and insufficient balance', () async {
      final cryptoService = WalletCryptoService();
      final keyPair = cryptoService.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );
      final adapter = FallbackRpcAdapter(bitcoinUtxoSats: 10000);
      final dio = Dio()..httpClientAdapter = adapter;
      final transferService = WalletTransferService(dio: dio);
      final asset = ChainBalance(
        chain: WalletChain.bitcoin,
        symbol: 'BTC',
        name: 'Bitcoin',
        amount: '0.0001',
        address: keyPair.bitcoinAddress,
        decimals: 8,
      );

      expect(
        () => transferService.estimateFee(
          asset: asset,
          toAddress: keyPair.bitcoinAddress,
          amount: '0.000001',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => transferService.estimateFee(
          asset: asset,
          toAddress: keyPair.bitcoinAddress,
          amount: '0.0001',
        ),
        throwsA(isA<StateError>()),
      );
      expect(adapter.bitcoinBroadcastCount, 0);
    });
  });
}

BigInt _littleEndianHexToInt(String value) {
  final bytes = <int>[];
  for (var index = 0; index < value.length; index += 2) {
    bytes.add(int.parse(value.substring(index, index + 2), radix: 16));
  }
  return BigInt.parse(
    bytes.reversed.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );
}

class _AptosTransferAdapter implements HttpClientAdapter {
  int simulateCount = 0;
  int moduleAbiRequestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.contains('/module/')) {
      moduleAbiRequestCount++;
    }
    if (path.endsWith('/estimate_gas_price')) {
      return _jsonResponse({
        'gas_estimate': 100,
        'deprioritized_gas_estimate': 50,
        'prioritized_gas_estimate': 150,
      });
    }
    if (path.contains('/accounts/') && !path.contains('/module/')) {
      final address = path.split('/').last;
      return _jsonResponse({
        'sequence_number': '0',
        'authentication_key': address,
      });
    }
    if (path.endsWith('/transactions/simulate')) {
      simulateCount++;
      return _jsonResponse([
        {
          'type': 'user_transaction',
          'version': '1',
          'hash': '0xaptossimulated',
          'state_change_hash': '0x0',
          'event_root_hash': '0x0',
          'state_checkpoint_hash': null,
          'gas_used': '10',
          'success': true,
          'vm_status': 'Executed successfully',
          'accumulator_root_hash': '0x0',
          'changes': [],
          'sender':
              '0xeb663b681209e7087d681c5d3eed12aaa8e1915e7c87794542c3f96e94b3d3bf',
          'sequence_number': '0',
          'max_gas_amount': '200000',
          'gas_unit_price': '100',
          'expiration_timestamp_secs': '2000000000',
          'payload': {
            'type': 'entry_function_payload',
            'function': '0x1::aptos_account::transfer',
            'type_arguments': [],
            'arguments': ['0x2', '1'],
          },
          'signature': null,
          'events': [],
          'timestamp': '1786756800000000',
        },
      ]);
    }
    return _jsonResponse({'message': 'not found'}, statusCode: 404);
  }

  ResponseBody _jsonResponse(Object data, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _BaseTransferAdapter implements HttpClientAdapter {
  final mainnetMethods = <String>[];
  final fallbackMethods = <String>[];
  String? lastOracleCallData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data;
    final method = data is Map ? data['method']?.toString() ?? '' : '';
    if (options.uri.host == 'mainnet.base.org') {
      mainnetMethods.add(method);
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'error': {'code': -32000, 'message': 'rate limited'},
      });
    }
    if (options.uri.host == 'base-rpc.publicnode.com') {
      fallbackMethods.add(method);
      if (method == 'eth_call' && data is Map) {
        final params = data['params'];
        final call = params is List && params.isNotEmpty ? params.first : null;
        if (call is Map) {
          lastOracleCallData = call['data']?.toString();
        }
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': '0x3b9aca00',
        });
      }
      final result = switch (method) {
        'eth_gasPrice' => '0x3b9aca00',
        'eth_estimateGas' => '0x5208',
        'eth_getTransactionCount' => '0x0',
        'eth_sendRawTransaction' => '0xbasehash',
        _ => '0x0',
      };
      return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': result});
    }
    return _jsonResponse({'message': 'not found'}, statusCode: 404);
  }

  ResponseBody _jsonResponse(Object data, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
