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
}
