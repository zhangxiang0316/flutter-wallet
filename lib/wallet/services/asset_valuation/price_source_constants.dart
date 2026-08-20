part of '../asset_valuation_service.dart';

/// 第三方行情接口请求头。
///
/// 部分公开接口会拒绝缺少 user-agent 的请求，这里使用移动端浏览器 UA 提高兼容性。
const Map<String, String> _requestHeaders = {
  'accept': 'application/json',
  'user-agent':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
      'Mobile/15E148 Safari/604.1',
};

/// 稳定币固定使用的 USD 单价。
final Decimal _oneUsd = Decimal.one;

/// 小额估值展示阈值。
///
/// 小于 0.01 时保留 6 位小数，否则用户会看到 0.00，误以为资产完全没有价值。
final Decimal _minimumDisplayValue = Decimal.parse('0.01');

/// 直接按 1 USD 计算的稳定币符号集合。
const Set<String> _stableSymbols = {'USDT', 'USDC', 'BUSD', 'TUSD', 'DAI'};

/// Binance 现货接口使用的交易对映射。
///
/// 应用内符号和交易所交易对不完全一致，例如 BTCB/WBTC 都需要映射到 BTCUSDT。
const Map<String, String> _binanceTickerSymbols = {
  'BNB': 'BNBUSDT',
  'TRX': 'TRXUSDT',
  'ETH': 'ETHUSDT',
  'BTC': 'BTCUSDT',
  'BTCB': 'BTCUSDT',
  'WBTC': 'BTCUSDT',
  'CBBTC': 'BTCUSDT',
  'WETH': 'ETHUSDT',
  'OKB': 'OKBUSDT',
  'SOL': 'SOLUSDT',
  'SUI': 'SUIUSDT',
  'APT': 'APTUSDT',
  'ARB': 'ARBUSDT',
  'POL': 'POLUSDT',
};

/// OKX 现货接口使用的交易对映射。
const Map<String, String> _okxTickerSymbols = {
  'BNB': 'BNB-USDT',
  'TRX': 'TRX-USDT',
  'ETH': 'ETH-USDT',
  'BTC': 'BTC-USDT',
  'BTCB': 'BTC-USDT',
  'WBTC': 'BTC-USDT',
  'CBBTC': 'BTC-USDT',
  'WETH': 'ETH-USDT',
  'OKB': 'OKB-USDT',
  'SOL': 'SOL-USDT',
  'SUI': 'SUI-USDT',
  'APT': 'APT-USDT',
  'ARB': 'ARB-USDT',
  'POL': 'POL-USDT',
};

/// CoinGecko/DeFiLlama 使用的币种 ID 映射。
///
/// DeFiLlama 的价格接口使用 `coingecko:<id>` 作为 key，所以两者共用这份映射。
const Map<String, String> _coingeckoIds = {
  'BNB': 'binancecoin',
  'TRX': 'tron',
  'ETH': 'ethereum',
  'BTC': 'bitcoin',
  'BTCB': 'bitcoin',
  'WBTC': 'bitcoin',
  'CBBTC': 'bitcoin',
  'WETH': 'ethereum',
  'OKB': 'okb',
  'SOL': 'solana',
  'SUI': 'sui',
  'APT': 'aptos',
  'ARB': 'arbitrum',
  'POL': 'polygon-ecosystem-token',
};

/// CoinPaprika 使用的币种 ID 映射。
const Map<String, String> _coinPaprikaIds = {
  'BNB': 'bnb-binance-coin',
  'TRX': 'trx-tron',
  'ETH': 'eth-ethereum',
  'BTC': 'btc-bitcoin',
  'BTCB': 'btc-bitcoin',
  'WBTC': 'btc-bitcoin',
  'CBBTC': 'btc-bitcoin',
  'WETH': 'eth-ethereum',
  'OKB': 'okb-okb',
  'SOL': 'sol-solana',
  'SUI': 'sui-sui',
  'APT': 'apt-aptos',
  'ARB': 'arb-arbitrum',
  'POL': 'pol-polygon-ecosystem-token',
};

/// CryptoCompare 接口使用的币种符号映射。
const Map<String, String> _cryptoCompareSymbols = {
  'BNB': 'BNB',
  'TRX': 'TRX',
  'ETH': 'ETH',
  'BTC': 'BTC',
  'BTCB': 'BTC',
  'WBTC': 'BTC',
  'CBBTC': 'BTC',
  'WETH': 'ETH',
  'OKB': 'OKB',
  'SOL': 'SOL',
  'SUI': 'SUI',
  'APT': 'APT',
  'ARB': 'ARB',
  'POL': 'POL',
};

/// 当前服务可以尝试获取实时价格的非稳定币集合。
///
/// 如果后续新增币种，需要至少在一个价格源映射中加入符号，才会进入询价流程。
final Set<String> _pricedSymbols = {
  ..._okxTickerSymbols.keys,
  ..._coingeckoIds.keys,
  ..._coinPaprikaIds.keys,
  ..._binanceTickerSymbols.keys,
  ..._cryptoCompareSymbols.keys,
};
