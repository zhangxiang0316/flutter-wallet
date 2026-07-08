import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:omnicast/wallet/constants/crypto_constants.dart';
import 'package:solana/solana.dart';

Map<String, dynamic> bscTokenTxItem({
  required String hash,
  required int timestamp,
}) {
  return {
    'blockNumber': timestamp.toString(),
    'timeStamp': timestamp.toString(),
    'hash': hash,
    'from': '0x1111111111111111111111111111111111111111',
    'to': '0x2222222222222222222222222222222222222222',
    'value': '2000000000000000000',
    'tokenDecimal': '18',
    'gasUsed': '21000',
    'gasPrice': '1000000000',
    'contractAddress': '0x55d398326f99059fF775485246999027B3197955',
  };
}

Map<String, dynamic> _moralisTokenTxItem({
  required String hash,
  required String value,
  String contractAddress = '0x55d398326f99059fF775485246999027B3197955',
  String tokenDecimals = '18',
  String timestamp = '2026-06-01T12:00:00.000Z',
  int logIndex = 1,
}) {
  return {
    'token_name': 'Tether USD',
    'token_symbol': 'USDT',
    'token_decimals': tokenDecimals,
    'transaction_hash': hash,
    'address': contractAddress,
    'block_timestamp': timestamp,
    'block_number': 123,
    'from_address': '0x1111111111111111111111111111111111111111',
    'to_address': '0x2222222222222222222222222222222222222222',
    'value': value,
    'log_index': logIndex,
  };
}

Map<String, dynamic> _xLayerTokenLog(
  String hash,
  int blockNumber,
  int logIndex,
) {
  const walletTopic =
      '0x0000000000000000000000001111111111111111111111111111111111111111';
  const recipientTopic =
      '0x0000000000000000000000002222222222222222222222222222222222222222';
  return {
    'transactionHash': hash,
    'blockNumber': '0x${blockNumber.toRadixString(16)}',
    'logIndex': '0x${logIndex.toRadixString(16)}',
    'data': '0x1bc16d674ec80000',
    'topics': [
      CryptoConstants.evmTransferEventTopic,
      walletTopic,
      recipientTopic,
    ],
  };
}

class FallbackRpcAdapter implements HttpClientAdapter {
  FallbackRpcAdapter({
    this.failBscScan = false,
    this.failTronGridAccount = false,
    this.hangSolana = false,
    this.solanaTokenAccountPubkey,
    this.solanaTokenAccountsByOwner,
    this.solanaTokenAccountBalances = const {},
    this.solanaHistoryOwner,
    this.solanaHistoryRecipient,
    this.heliusOwner,
    this.heliusRecipient,
    this.heliusMint,
    this.heliusFullPage = false,
    this.failHeliusRateLimit = false,
    this.failMoralisInvalidApiKey = false,
    this.heliusUseAccountData = false,
    this.bscScanResultsByPage,
    this.bscScanDeprecated = false,
    this.bscTokenLogsFail = false,
    this.bscTokenReceiptLookup = false,
    this.moralisEmptyTokenPage = false,
    this.moralisTokenFullPage = false,
    this.failEtherscanV2 = false,
    this.xLayerTokenLogFullPage = false,
  });

  final bool failBscScan;
  final bool failTronGridAccount;
  final bool hangSolana;
  final String? solanaTokenAccountPubkey;
  final List<Map<String, dynamic>>? solanaTokenAccountsByOwner;
  final Map<String, Map<String, dynamic>> solanaTokenAccountBalances;
  final String? solanaHistoryOwner;
  final String? solanaHistoryRecipient;
  final String? heliusOwner;
  final String? heliusRecipient;
  final String? heliusMint;
  final bool heliusFullPage;
  final bool failHeliusRateLimit;
  final bool failMoralisInvalidApiKey;
  final bool heliusUseAccountData;
  final Map<int, List<Map<String, dynamic>>>? bscScanResultsByPage;
  final bool bscScanDeprecated;
  final bool bscTokenLogsFail;
  final bool bscTokenReceiptLookup;
  final bool moralisEmptyTokenPage;
  final bool moralisTokenFullPage;
  final bool failEtherscanV2;
  final bool xLayerTokenLogFullPage;
  final calls = <String>[];
  final bscScanPages = <int>[];
  final bscScanOffsets = <int>[];
  final moralisChains = <String>[];
  final moralisCursors = <String>[];
  final moralisContractFilters = <List<String>>[];
  final xLayerLogRanges = <(int, int)>[];
  final etherscanV2ChainIds = <String>[];
  final arbiscanApiKeys = <String>[];
  final solanaMethods = <String>[];
  final solanaRpcApiKeys = <String>[];
  Map<String, dynamic> tronGridHeaders = const {};
  String? lastSolanaTransactionBase64;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final origin = '${options.uri.scheme}://${options.uri.host}';
    calls.add(origin);

    if (origin == 'https://deep-index.moralis.io') {
      if (failMoralisInvalidApiKey) {
        return _jsonResponse({'message': 'invalid api key'}, statusCode: 403);
      }
      moralisChains.add(options.uri.queryParameters['chain'] ?? '');
      final cursor = options.uri.queryParameters['cursor'] ?? '';
      moralisCursors.add(cursor);
      final contractFilters =
          options.uri.queryParametersAll['contract_addresses'] ?? const [];
      final contractAddress = contractFilters.isNotEmpty
          ? contractFilters.first
          : '0x55d398326f99059fF775485246999027B3197955';
      if (contractFilters.isNotEmpty) {
        moralisContractFilters.add(contractFilters);
      }
      if (options.uri.path.endsWith('/erc20/transfers')) {
        if (moralisEmptyTokenPage) {
          return _jsonResponse({'result': [], 'cursor': 'moralis-empty-next'});
        }
        if (cursor == 'moralis-next') {
          return _jsonResponse({
            'result': [
              _moralisTokenTxItem(
                hash: '0xmoralis-token-next',
                value: '3000000000000000000',
                contractAddress: contractAddress,
              ),
            ],
            'cursor': null,
          });
        }
        final count = moralisTokenFullPage ? 30 : 1;
        return _jsonResponse({
          'result': List.generate(
            count,
            (index) => _moralisTokenTxItem(
              hash: '0xmoralis-token-$index',
              value: '2000000000000000000',
              contractAddress: contractAddress,
              timestamp:
                  '2026-06-01T12:00:${index.toString().padLeft(2, '0')}Z',
              logIndex: index,
            ),
          ),
          'cursor': moralisTokenFullPage ? 'moralis-next' : null,
        });
      }
      return _jsonResponse({
        'result': [
          {
            'hash': '0xmoralisnative',
            'from_address': '0x2222222222222222222222222222222222222222',
            'to_address': '0x1111111111111111111111111111111111111111',
            'value': '1250000000000000000',
            'gas_price': '1000000000',
            'receipt_gas_used': '21000',
            'receipt_status': '1',
            'transaction_fee': '0.000021',
            'block_number': 123,
            'block_timestamp': '2026-06-01T12:00:00.000Z',
          },
        ],
        'cursor': null,
      });
    }

    if (origin == 'https://api.helius.xyz') {
      if (failHeliusRateLimit) {
        return _jsonResponse({'error': 'rate limited'}, statusCode: 429);
      }
      final owner = heliusOwner ?? '';
      final other = heliusRecipient ?? '';
      final mint = heliusMint ?? '';
      if (heliusUseAccountData && mint.isEmpty) {
        return _jsonResponse([
          {
            'signature': 'helius-sol-account-data',
            'timestamp': 1700000000,
            'slot': 123,
            'fee': 5000,
            'transactionError': null,
            'nativeTransfers': [],
            'accountData': [
              {'account': owner, 'nativeBalanceChange': -250000000},
            ],
          },
        ]);
      }
      if (heliusUseAccountData && mint.isNotEmpty) {
        return _jsonResponse([
          {
            'signature': 'helius-token-account-data',
            'timestamp': 1700000000,
            'slot': 123,
            'fee': 5000,
            'transactionError': null,
            'tokenTransfers': [],
            'accountData': [
              {
                'account': owner,
                'nativeBalanceChange': 0,
                'tokenBalanceChanges': [
                  {
                    'userAccount': owner,
                    'mint': mint,
                    'rawTokenAmount': {'tokenAmount': '2500000', 'decimals': 6},
                  },
                ],
              },
            ],
          },
        ]);
      }
      if (mint.isNotEmpty) {
        final count = heliusFullPage ? 50 : 1;
        return _jsonResponse(
          List.generate(count, (index) {
            return {
              'signature': 'helius-token-signature-$index',
              'timestamp': 1700000000 - index,
              'slot': 123 - index,
              'fee': 5000,
              'transactionError': null,
              'tokenTransfers': [
                {
                  'fromUserAccount': other,
                  'toUserAccount': owner,
                  'mint': mint,
                  'tokenAmount': 2.5,
                  'rawTokenAmount': {'tokenAmount': '2500000', 'decimals': 6},
                },
              ],
            };
          }),
        );
      }
      return _jsonResponse([
        {
          'signature': 'helius-sol-signature',
          'timestamp': 1700000000,
          'slot': 123,
          'fee': 5000,
          'transactionError': null,
          'nativeTransfers': [
            {
              'fromUserAccount': owner,
              'toUserAccount': other,
              'amount': 1250000000,
            },
          ],
        },
      ]);
    }

    if (origin == 'https://bsc-dataseed.bnbchain.org') {
      final method = _evmMethod(options.data);
      if (bscTokenReceiptLookup) {
        if (method == 'eth_getTransactionReceipt') {
          return _jsonResponse({
            'jsonrpc': '2.0',
            'id': 1,
            'result': {
              'from': '0x1111111111111111111111111111111111111111',
              'to': '0x55d398326f99059ff775485246999027b3197955',
              'status': '0x1',
              'gasUsed': '0x86c7',
              'effectiveGasPrice': '0x2faf080',
              'blockNumber': '0x660e209',
              'transactionHash': '0xreceipt-token',
              'logs': [
                {
                  'address': '0x55d398326f99059ff775485246999027b3197955',
                  'topics': [
                    CryptoConstants.evmTransferEventTopic,
                    '0x0000000000000000000000001111111111111111111111111111111111111111',
                    '0x0000000000000000000000002222222222222222222222222222222222222222',
                  ],
                  'data': '0x38d7ea4c68000',
                  'blockNumber': '0x660e209',
                  'transactionHash': '0xreceipt-token',
                  'blockTimestamp': '0x6a420fb4',
                  'logIndex': '0x262',
                },
              ],
            },
          });
        }
        if (method == 'eth_getBlockByNumber') {
          return _jsonResponse({
            'jsonrpc': '2.0',
            'id': 1,
            'result': {'timestamp': '0x6a420fb4'},
          });
        }
      }
      if (bscTokenLogsFail) {
        if (method == 'eth_blockNumber') {
          return _jsonResponse({
            'jsonrpc': '2.0',
            'id': 1,
            'result': '0x6755507',
          });
        }
        if (method == 'eth_getLogs') {
          return _jsonResponse({
            'jsonrpc': '2.0',
            'id': 1,
            'error': {'code': -32005, 'message': 'limit exceeded'},
          });
        }
      }
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'error': {'code': -32000, 'message': 'temporary upstream error'},
      });
    }

    if (origin == 'https://bsc-rpc.publicnode.com') {
      final method = _evmMethod(options.data);
      if (bscTokenLogsFail && method == 'eth_getLogs') {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'error': {
            'code': -32602,
            'message': 'Archive requests require a personal token',
          },
        });
      }
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'result': _isEvmChainIdRequest(options.data)
            ? '0x38'
            : _isEvmNativeRequest(options.data)
            ? '0x0de0b6b3a7640000'
            : '0x0',
      });
    }

    if (origin == 'https://api.bscscan.com' && options.uri.path == '/api') {
      final page = int.tryParse(options.uri.queryParameters['page'] ?? '') ?? 1;
      final offset =
          int.tryParse(options.uri.queryParameters['offset'] ?? '') ?? 0;
      bscScanPages.add(page);
      bscScanOffsets.add(offset);
      if (bscScanDeprecated) {
        return _jsonResponse({
          'status': '0',
          'message': 'NOTOK',
          'result':
              'You are using a deprecated V1 endpoint, switch to Etherscan API V2',
        });
      }
      if (failBscScan) {
        return _jsonResponse({
          'status': '0',
          'message': 'NOTOK',
          'result': 'Explorer unavailable',
        });
      }
      final pageResults = bscScanResultsByPage?[page];
      if (pageResults != null) {
        return _jsonResponse({
          'status': pageResults.isEmpty ? '0' : '1',
          'message': pageResults.isEmpty ? 'No transactions found' : 'OK',
          'result': pageResults.isEmpty ? 'No transactions found' : pageResults,
        });
      }
      return _jsonResponse({
        'status': '1',
        'message': 'OK',
        'result': [
          {
            'blockNumber': '123',
            'timeStamp': '1700000000',
            'hash': '0xbeef',
            'from': '0x1111111111111111111111111111111111111111',
            'to': '0x2222222222222222222222222222222222222222',
            'value': '2000000000000000000',
            'tokenDecimal': '18',
            'gasUsed': '21000',
            'gasPrice': '1000000000',
            'contractAddress': '0x55d398326f99059fF775485246999027B3197955',
          },
        ],
      });
    }

    if (origin == 'https://api.etherscan.io' && options.uri.path == '/v2/api') {
      etherscanV2ChainIds.add(options.uri.queryParameters['chainid'] ?? '');
      if (failEtherscanV2) {
        return _jsonResponse({
          'status': '0',
          'message': 'NOTOK',
          'result': 'Etherscan V2 unavailable',
        });
      }
      final contractAddress =
          options.uri.queryParameters['contractaddress'] ??
          '0x55d398326f99059fF775485246999027B3197955';
      return _jsonResponse({
        'status': '1',
        'message': 'OK',
        'result': [
          bscTokenTxItem(hash: '0xetherscanv2', timestamp: 1700000000)
            ..['contractAddress'] = contractAddress,
        ],
      });
    }

    if (origin == 'https://api.arbiscan.io' && options.uri.path == '/api') {
      arbiscanApiKeys.add(options.uri.queryParameters['apikey'] ?? '');
      final contractAddress =
          options.uri.queryParameters['contractaddress'] ??
          '0xaf88d065e77c8cC2239327C5EDb3A432268e5831';
      return _jsonResponse({
        'status': '1',
        'message': 'OK',
        'result': [
          {
            'blockNumber': '475368948',
            'timeStamp': '1781953319',
            'hash': '0xarbiscan',
            'from': '0x1111111111111111111111111111111111111111',
            'to': '0x2222222222222222222222222222222222222222',
            'value': '50505051',
            'tokenDecimal': '6',
            'gasUsed': '21000',
            'gasPrice': '100000000',
            'contractAddress': contractAddress,
          },
        ],
      });
    }

    if (origin == 'https://api.etherscan.io' && options.uri.path == '/api') {
      return _jsonResponse({
        'status': '0',
        'message': 'NOTOK',
        'result': 'Missing/Invalid API Key',
      });
    }

    if (origin == 'https://eth.blockscout.com' &&
        options.uri.path.endsWith('/transactions')) {
      return _jsonResponse({
        'items': [
          {
            'hash': '0xblocknative',
            'from': {'hash': '0x2222222222222222222222222222222222222222'},
            'to': {'hash': '0x1111111111111111111111111111111111111111'},
            'value': '100000000000000000',
            'fee': {'value': '21000000000000'},
            'status': 'ok',
            'result': 'success',
            'block_number': 123,
            'timestamp': '2026-06-01T12:00:00.000000Z',
          },
        ],
        'next_page_params': null,
      });
    }

    if (origin == 'https://eth.blockscout.com' &&
        options.uri.path.endsWith('/token-transfers')) {
      return _jsonResponse({
        'items': [
          {
            'transaction_hash': '0xwrongtoken',
            'from': {'hash': '0x2222222222222222222222222222222222222222'},
            'to': {'hash': '0x1111111111111111111111111111111111111111'},
            'token': {
              'address_hash': '0x0000000000000000000000000000000000000000',
              'decimals': '18',
            },
            'total': {'decimals': '18', 'value': '1'},
            'log_index': 1,
            'block_number': 122,
            'timestamp': '2026-06-01T11:00:00.000000Z',
          },
          {
            'transaction_hash': '0xblocktoken',
            'from': {'hash': '0x1111111111111111111111111111111111111111'},
            'to': {'hash': '0x2222222222222222222222222222222222222222'},
            'token': {
              'address_hash': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
              'decimals': '6',
            },
            'total': {'decimals': '6', 'value': '2500000'},
            'log_index': 2,
            'block_number': 124,
            'timestamp': '2026-06-01T12:30:00.000000Z',
          },
        ],
        'next_page_params': null,
      });
    }

    if (origin == 'https://rpc.xlayer.tech') {
      final method = _evmMethod(options.data);
      if (method == 'eth_blockNumber') {
        return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0xf4240'});
      }
      if (method == 'eth_getLogs') {
        final filter = _firstEvmParamMap(options.data);
        final fromBlock = _hexToInt(filter['fromBlock']?.toString() ?? '0x0');
        final toBlock = _hexToInt(filter['toBlock']?.toString() ?? '0x0');
        final topics = filter['topics'];
        final isOutgoing =
            topics is List && topics.length > 1 && topics[1] != null;
        if (isOutgoing) {
          xLayerLogRanges.add((fromBlock, toBlock));
          if (toBlock == 500000) {
            return _jsonResponse({
              'jsonrpc': '2.0',
              'id': 1,
              'result': [_xLayerTokenLog('0xxlayerold', 499999, 1)],
            });
          }
          if (xLayerTokenLogFullPage && toBlock == 1000000) {
            return _jsonResponse({
              'jsonrpc': '2.0',
              'id': 1,
              'result': List.generate(
                30,
                (index) =>
                    _xLayerTokenLog('0xxlayer$index', 1000000 - index, index),
              ),
            });
          }
        }
        return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': []});
      }
      if (method == 'eth_getTransactionReceipt') {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'status': '0x1',
            'gasUsed': '0x5208',
            'effectiveGasPrice': '0x3b9aca00',
          },
        });
      }
      if (method == 'eth_getBlockByNumber') {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {'timestamp': '0x6553f100'},
        });
      }
      return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0x0'});
    }

    if (origin == 'https://ethereum-rpc.publicnode.com' ||
        origin == 'https://arbitrum-one-rpc.publicnode.com' ||
        origin == 'https://arbitrum.llamarpc.com' ||
        origin == 'https://arb1.arbitrum.io') {
      return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0x0'});
    }

    if (origin == 'https://polygon-rpc.com') {
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'result': _isEvmChainIdRequest(options.data) ? '0x89' : '0x0',
      });
    }

    if (origin == 'https://polygon-rpc-disabled.example') {
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'error': {'code': -32051, 'message': 'API key disabled'},
      });
    }

    if (origin == 'https://polygon-bor-rpc.publicnode.com') {
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'result': _isEvmChainIdRequest(options.data) ? '0x89' : '0x0',
      });
    }

    if (origin == 'https://solana-mainnet.rpc.extrnode.com' ||
        origin == 'https://rpc.ankr.com' ||
        origin == 'https://solana-rpc.publicnode.com' ||
        origin == 'https://api.mainnet-beta.solana.com' ||
        origin == 'https://mainnet.helius-rpc.com') {
      if (hangSolana) {
        throw TimeoutException('Solana balance lookup timed out');
      }
      final apiKey = options.uri.queryParameters['api-key'];
      if (apiKey != null && apiKey.isNotEmpty) {
        solanaRpcApiKeys.add(apiKey);
      }
      final method = _solanaMethod(options.data);
      if (method != null) {
        solanaMethods.add(method);
      }
      if (_isSolanaMethod(options.data, 'getBalance')) {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {'value': 1000000000},
        });
      }
      if (_isSolanaMethod(options.data, 'getTokenAccountBalance')) {
        final account = _firstSolanaParam(options.data);
        final tokenBalance = solanaTokenAccountBalances[account];
        if (tokenBalance == null) {
          return _jsonResponse({
            'jsonrpc': '2.0',
            'id': 1,
            'error': {'code': -32602, 'message': 'could not find account'},
          });
        }
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {'value': tokenBalance},
        });
      }
      if (_isSolanaMethod(options.data, 'getTokenAccountsByOwner')) {
        final pubkey = solanaTokenAccountPubkey;
        final accounts = solanaTokenAccountsByOwner;
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'value':
                accounts ??
                (pubkey == null
                    ? []
                    : [
                        {'pubkey': pubkey},
                      ]),
          },
        });
      }
      if (_isSolanaMethod(options.data, 'getLatestBlockhash')) {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'context': {'slot': 1},
            'value': {
              'blockhash': '11111111111111111111111111111111',
              'lastValidBlockHeight': 1,
            },
          },
        });
      }
      if (_isSolanaMethod(options.data, 'getSignaturesForAddress')) {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': [
            {'signature': 'solana-history-signature'},
          ],
        });
      }
      if (_isSolanaMethod(options.data, 'getParsedTransaction')) {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'blockTime': 1700000000,
            'meta': {'err': null, 'fee': 5000},
            'transaction': {
              'message': {
                'instructions': [
                  {
                    'program': 'system',
                    'parsed': {
                      'type': 'transfer',
                      'info': {
                        'source': solanaHistoryOwner ?? '',
                        'destination': solanaHistoryRecipient ?? '',
                        'lamports': 1250000000,
                      },
                    },
                  },
                ],
              },
            },
          },
        });
      }
      if (_isSolanaMethod(options.data, 'sendTransaction')) {
        final params = options.data is Map ? options.data['params'] : null;
        if (params is List && params.isNotEmpty && params.first is String) {
          lastSolanaTransactionBase64 = params.first as String;
        }
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': 'solana-signature',
        });
      }
    }

    if (origin == 'https://api.trongrid.io' &&
        options.uri.path == '/wallet/getaccount') {
      tronGridHeaders = options.headers;
      if (failTronGridAccount) {
        return _jsonResponse({
          'Error': 'temporary upstream error',
        }, statusCode: 500);
      }
      return _jsonResponse({'balance': 0});
    }

    if (origin == 'https://tron-rpc.publicnode.com' &&
        options.uri.path == '/wallet/getaccount') {
      return _jsonResponse({'balance': 1000000});
    }

    if (origin == 'https://api.trongrid.io' &&
        options.uri.path.startsWith('/v1/accounts/')) {
      if (options.uri.path.endsWith('/transactions/trc20')) {
        return _jsonResponse({
          'data': [
            {
              'transaction_id': 'tronhash1',
              'from': 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
              'to': 'TKn1ErhSZJD7GBuVxMqowPJ7YxXQwfGKEp',
              'value': '2500000',
              'token_info': {'decimals': 6},
              'block_timestamp': 1700000000000,
            },
          ],
        });
      }
      return _jsonResponse({'data': []});
    }

    return _jsonResponse({}, statusCode: 404);
  }

  bool _isEvmNativeRequest(dynamic data) {
    return data is Map && data['method'] == 'eth_getBalance';
  }

  bool _isEvmChainIdRequest(dynamic data) {
    return data is Map && data['method'] == 'eth_chainId';
  }

  String? _evmMethod(dynamic data) {
    return data is Map ? data['method']?.toString() : null;
  }

  Map<dynamic, dynamic> _firstEvmParamMap(dynamic data) {
    final params = data is Map ? data['params'] : null;
    if (params is List && params.isNotEmpty && params.first is Map) {
      return params.first as Map;
    }
    return const {};
  }

  int _hexToInt(String value) {
    final normalized = value.replaceFirst('0x', '');
    if (normalized.isEmpty) return 0;
    return int.parse(normalized, radix: 16);
  }

  bool _isSolanaMethod(dynamic data, String method) {
    return data is Map && data['method'] == method;
  }

  String? _solanaMethod(dynamic data) {
    return data is Map ? data['method']?.toString() : null;
  }

  String? _firstSolanaParam(dynamic data) {
    final params = data is Map ? data['params'] : null;
    if (params is! List || params.isEmpty) {
      return null;
    }
    return params.first?.toString();
  }

  ResponseBody _jsonResponse(Object data, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<String> solanaAssociatedTokenAddress({
  required String ownerAddress,
  required String mintAddress,
}) async {
  final owner = Ed25519HDPublicKey.fromBase58(ownerAddress);
  final mint = Ed25519HDPublicKey.fromBase58(mintAddress);
  final ata = await findAssociatedTokenAddress(owner: owner, mint: mint);
  return ata.toBase58();
}

Map<String, dynamic> solanaTokenBalance({
  required String amount,
  required int decimals,
}) {
  return {'amount': amount, 'decimals': decimals};
}
