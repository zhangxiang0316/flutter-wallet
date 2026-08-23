import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/browser/controller/block_explorer_navigation_policy.dart';

void main() {
  group('BlockExplorerNavigationPolicy', () {
    late BlockExplorerNavigationPolicy policy;

    setUp(() {
      policy = BlockExplorerNavigationPolicy(
        Uri.parse('https://basescan.org/address/0x1234'),
      );
    });

    test('allows HTTPS navigation on the configured origin', () {
      final decision = policy.evaluate(
        'https://basescan.org/tx/0xabcd?tab=logs#event',
        isMainFrame: true,
      );

      expect(decision.disposition, BlockExplorerNavigationDisposition.navigate);
      expect(decision.uri?.host, 'basescan.org');
    });

    test('normalizes host case and a trailing dot', () {
      final trailingDotPolicy = BlockExplorerNavigationPolicy(
        Uri.parse('https://BASESCAN.ORG./address/0x1234'),
      );

      final decision = trailingDotPolicy.evaluate(
        'https://basescan.org/tx/0xabcd',
        isMainFrame: true,
      );

      expect(decision.disposition, BlockExplorerNavigationDisposition.navigate);
    });

    test('opens a cross-origin HTTPS main-frame link externally', () {
      final decision = policy.evaluate(
        'https://docs.base.org/learn',
        isMainFrame: true,
      );

      expect(
        decision.disposition,
        BlockExplorerNavigationDisposition.openExternally,
      );
      expect(decision.uri, Uri.parse('https://docs.base.org/learn'));
    });

    test('blocks cross-origin subframe navigation', () {
      final decision = policy.evaluate(
        'https://third-party.example/widget',
        isMainFrame: false,
      );

      expect(decision.disposition, BlockExplorerNavigationDisposition.block);
      expect(
        decision.blockReason,
        BlockExplorerNavigationBlockReason.crossOriginSubframe,
      );
    });

    test('does not trust lookalike hosts or another HTTPS port', () {
      final lookalike = policy.evaluate(
        'https://basescan.org.attacker.example/tx/0xabcd',
        isMainFrame: true,
      );
      final portChanged = policy.evaluate(
        'https://basescan.org:444/tx/0xabcd',
        isMainFrame: true,
      );

      expect(
        lookalike.disposition,
        BlockExplorerNavigationDisposition.openExternally,
      );
      expect(
        portChanged.disposition,
        BlockExplorerNavigationDisposition.openExternally,
      );
    });

    test('blocks HTTP and non-HTTPS navigation', () {
      for (final url in [
        'http://basescan.org/tx/0xabcd',
        'mailto:support@basescan.org',
        'tel:+123456789',
      ]) {
        final decision = policy.evaluate(url, isMainFrame: true);

        expect(decision.disposition, BlockExplorerNavigationDisposition.block);
      }
    });

    test('blocks dangerous schemes', () {
      for (final url in [
        'javascript://basescan.org/alert(1)',
        'data://basescan.org/text/html,payload',
        'file://basescan.org/etc/passwd',
        'content://basescan.org/private',
        'intent://basescan.org/#Intent;end',
      ]) {
        final decision = policy.evaluate(url, isMainFrame: true);

        expect(decision.disposition, BlockExplorerNavigationDisposition.block);
        expect(
          decision.blockReason,
          BlockExplorerNavigationBlockReason.dangerousScheme,
          reason: url,
        );
      }
    });

    test('blocks malformed URLs and URLs containing credentials', () {
      final malformed = policy.evaluate('not a URL', isMainFrame: true);
      final credentials = policy.evaluate(
        'https://user:password@basescan.org/tx/0xabcd',
        isMainFrame: true,
      );

      expect(malformed.disposition, BlockExplorerNavigationDisposition.block);
      expect(credentials.disposition, BlockExplorerNavigationDisposition.block);
    });

    test('rejects an unsafe initial explorer URL', () {
      expect(
        () => BlockExplorerNavigationPolicy(
          Uri.parse('http://basescan.org/address/0x1234'),
        ),
        throwsArgumentError,
      );
      expect(
        () => BlockExplorerNavigationPolicy(
          Uri.parse('https://user:password@basescan.org/address/0x1234'),
        ),
        throwsArgumentError,
      );
    });

    test('only treats credential-free HTTPS URLs as safe externally', () {
      expect(
        BlockExplorerNavigationPolicy.isSafeHttpsUri(
          Uri.parse('https://basescan.org/tx/0xabcd'),
        ),
        isTrue,
      );
      expect(
        BlockExplorerNavigationPolicy.isSafeHttpsUri(
          Uri.parse('http://basescan.org/tx/0xabcd'),
        ),
        isFalse,
      );
      expect(
        BlockExplorerNavigationPolicy.isSafeHttpsUri(
          Uri.parse('https://user@basescan.org/tx/0xabcd'),
        ),
        isFalse,
      );
    });
  });
}
