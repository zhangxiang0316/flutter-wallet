/// Runtime configuration for third-party transaction history APIs.
///
/// Values are injected with `--dart-define` so real API keys do not need to be
/// committed to source control.
class WalletHistoryApiConfig {
  const WalletHistoryApiConfig({
    this.etherscanApiKey = _etherscanApiKey,
    this.tronGridApiKey = _tronGridApiKey,
  });

  static const String _etherscanApiKey = String.fromEnvironment(
    'ETHERSCAN_API_KEY',
  );
  static const String _tronGridApiKey = String.fromEnvironment(
    'TRONGRID_API_KEY',
  );

  /// Etherscan V2 API key. A single key can be used for supported EVM chains.
  final String etherscanApiKey;

  /// TronGrid API key for TRON/TRC20 transaction history.
  final String tronGridApiKey;

  bool get hasEtherscanApiKey => etherscanApiKey.trim().isNotEmpty;

  bool get hasTronGridApiKey => tronGridApiKey.trim().isNotEmpty;
}
