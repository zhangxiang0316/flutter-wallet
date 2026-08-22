import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/transfer/controller/transfer_scan_address_parser.dart';
import 'package:omnicast/wallet/models/payment_request.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';

void main() {
  group('TransferScanAddressParser Bitcoin', () {
    const address = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';

    test('extracts a native SegWit address', () {
      expect(
        TransferScanAddressParser.extract(address, WalletChain.bitcoin.config),
        address,
      );
    });

    test('extracts an address from a BIP21 URI', () {
      expect(
        TransferScanAddressParser.extract(
          'bitcoin:$address?amount=0.001',
          WalletChain.bitcoin.config,
        ),
        address,
      );
    });
  });

  group('TransferScanAddressParser Sui', () {
    const address =
        '0x936accb491f0facaac668baaedcf4d0cfc6da1120b66f77fa6a43af718669973';

    test('extracts a 32-byte hexadecimal address', () {
      expect(
        TransferScanAddressParser.extract(address, WalletChain.sui.config),
        address,
      );
    });

    test('extracts an address from a Sui URI', () {
      expect(
        TransferScanAddressParser.extract(
          'sui:$address?amount=1',
          WalletChain.sui.config,
        ),
        address,
      );
    });
  });

  group('TransferScanAddressParser Aptos', () {
    const shortAddress = '0x1';
    const longAddress =
        '0x936accb491f0facaac668baaedcf4d0cfc6da1120b66f77fa6a43af718669973';

    test('extracts short and long hexadecimal addresses', () {
      expect(
        TransferScanAddressParser.extract(
          shortAddress,
          WalletChain.aptos.config,
        ),
        shortAddress,
      );
      expect(
        TransferScanAddressParser.extract(
          longAddress,
          WalletChain.aptos.config,
        ),
        longAddress,
      );
    });

    test('extracts an address from an Aptos URI', () {
      expect(
        TransferScanAddressParser.extract(
          'aptos:$longAddress?amount=1',
          WalletChain.aptos.config,
        ),
        longAddress,
      );
    });
  });

  group('TransferScanAddressParser payment requests', () {
    const evmAddress = '0x2222222222222222222222222222222222222222';
    const tronAddress = 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC';
    const solanaAddress = 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8';
    const bitcoinAddress = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
    const longHexAddress =
        '0x936accb491f0facaac668baaedcf4d0cfc6da1120b66f77fa6a43af718669973';

    test('preserves every field and detects Polygon from Ethereum', () {
      final uri = const PaymentRequest(
        scheme: 'omnicast',
        chainId: 'polygon',
        address: evmAddress,
        symbol: 'USDC',
        contractAddress: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
        amount: '12.5',
        memo: 'invoice 42',
      ).toUri();

      final request = TransferScanAddressParser.parse(
        uri.toString(),
        WalletChain.ethereum.config,
      );

      expect(request, isNotNull);
      expect(request!.scheme, 'omnicast');
      expect(request.chainId, 'polygon');
      expect(request.address, evmAddress);
      expect(request.symbol, 'USDC');
      expect(
        request.contractAddress,
        '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
      );
      expect(request.amount, '12.5');
      expect(request.memo, 'invoice 42');
    });

    test('parses TRON, Solana, Bitcoin, Sui, Aptos and EVM requests', () {
      final cases = <(WalletChain, String)>[
        (WalletChain.tron, tronAddress),
        (WalletChain.solana, solanaAddress),
        (WalletChain.bitcoin, bitcoinAddress),
        (WalletChain.sui, longHexAddress),
        (WalletChain.aptos, longHexAddress),
        (WalletChain.base, evmAddress),
      ];

      for (final entry in cases) {
        final payload = PaymentRequest(
          scheme: 'omnicast',
          chainId: entry.$1.id,
          address: entry.$2,
          symbol: entry.$1.symbol,
        ).toUri().toString();
        final parsed = TransferScanAddressParser.parse(
          payload,
          WalletChain.ethereum.config,
        );
        expect(parsed?.chainId, entry.$1.id, reason: entry.$1.name);
        expect(parsed?.address, entry.$2, reason: entry.$1.name);
      }
    });

    test('detects an EIP-681 numeric chain ID', () {
      final request = TransferScanAddressParser.parse(
        'ethereum:$evmAddress@137?amount=1',
        WalletChain.ethereum.config,
      );

      expect(request?.chainId, WalletChain.polygon.id);
      expect(request?.amount, '1');
    });

    test('marks a pure address as current-network-only', () {
      final request = TransferScanAddressParser.parse(
        evmAddress,
        WalletChain.base.config,
      );

      expect(request?.isPlainAddress, isTrue);
      expect(request?.scheme, isEmpty);
      expect(request?.chainId, WalletChain.base.id);
    });

    test('rejects unknown schemes, arbitrary text and damaged requests', () {
      expect(
        TransferScanAddressParser.parse(
          'https://example.com/pay?address=$evmAddress',
          WalletChain.ethereum.config,
        ),
        isNull,
      );
      expect(
        TransferScanAddressParser.parse(
          'send funds to $evmAddress',
          WalletChain.ethereum.config,
        ),
        isNull,
      );
      expect(
        TransferScanAddressParser.parse(
          'omnicast://receive?address=$evmAddress&amount=abc',
          WalletChain.ethereum.config,
        ),
        isNull,
      );
    });
  });
}
