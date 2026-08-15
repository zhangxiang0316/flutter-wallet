import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/transfer/controller/transfer_scan_address_parser.dart';
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
}
