/// Runtime configuration for third-party transaction history APIs.
class WalletHistoryApiConfig {
  const WalletHistoryApiConfig({
    this.etherscanApiKey = _etherscanApiKey,
    this.tronGridApiKey = _tronGridApiKey,
    this.heliusApiKey = _heliusApiKey,
    this.heliusBaseUrl = _heliusBaseUrl,
    this.moralisApiKey = _moralisApiKey,
    this.moralisBaseUrl = _moralisBaseUrl,
  });

  static const String _etherscanApiKey = String.fromEnvironment(
    'ETHERSCAN_API_KEY',
    defaultValue: '5NIP6PR3N1AXX8GDH83QGBQ87HPPPCFN6C',
  );
  static const String _tronGridApiKey = String.fromEnvironment(
    'TRONGRID_API_KEY',
  );
  static const String _heliusApiKey = String.fromEnvironment('HELIUS_API_KEY');
  static const String _heliusBaseUrl = String.fromEnvironment(
    'HELIUS_BASE_URL',
    defaultValue: 'https://api.helius.xyz/v0',
  );
  static const String _moralisApiKey = String.fromEnvironment(
    'MORALIS_API_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJub25jZSI6IjVjMDVlNzYyLTFiYTItNGI3NS1iYzcxLWZkNjMxZjg5MTAwMiIsIm9yZ0lkIjoiNTIyNDE4IiwidXNlcklkIjoiNTM3NjM5IiwidHlwZUlkIjoiNWQ2MWViNDktZGYzMC00NWQ3LTkxNjgtZTNkN2VkNWE3ZmNmIiwidHlwZSI6IlBST0pFQ1QiLCJpYXQiOjE3ODI4OTA3NjgsImV4cCI6NDkzODY1MDc2OH0.gy9pZRHJbPMOuZ49papnKPQ-qbmwPeo1ETvcXiCezNo'
  );
  static const String _moralisBaseUrl = String.fromEnvironment(
    'MORALIS_BASE_URL',
    defaultValue: 'https://deep-index.moralis.io/api/v2.2',
  );

  /// Etherscan V2 API key. A single key can be used for supported EVM chains.
  final String etherscanApiKey;

  /// TronGrid API key for TRON/TRC20 transaction history.
  final String tronGridApiKey;

  /// Helius API key for Solana/SPL transaction history.
  final String heliusApiKey;

  /// Helius API base URL. Kept configurable for tests and proxy deployments.
  final String heliusBaseUrl;

  /// Moralis API key for BSC native and BEP20 transaction history.
  final String moralisApiKey;

  /// Moralis API base URL. Kept configurable for tests and proxy deployments.
  final String moralisBaseUrl;

  bool get hasEtherscanApiKey => etherscanApiKey.trim().isNotEmpty;

  bool get hasTronGridApiKey => tronGridApiKey.trim().isNotEmpty;

  bool get hasHeliusApiKey => heliusApiKey.trim().isNotEmpty;

  bool get hasMoralisApiKey => moralisApiKey.trim().isNotEmpty;
}
