# 首页按代币聚合改造方案

## 1. 背景与目标

当前首页以区块链网络为一级结构，用户需要先展开网络，才能查看该网络下的代币余额。改造后的首页以代币为一级结构，直接展示常用代币在所有支持网络中的总数量和总估值；点击代币后，再查看它在各网络上的余额，并可继续进入已有的单链交易记录页。

目标数据流：

```text
多链余额列表
  -> 可信代币身份解析
  -> 按 canonicalTokenId 聚合
  -> 首页代币组合列表
  -> 代币多链详情
  -> 现有单链交易记录
```

本次改造不调整 RPC 余额协议、钱包密钥、转账签名和余额缓存格式。

## 2. 产品规则

### 2.1 首页展示

- 首页展示当前钱包全部可见资产，按 USD 总价值降序排列。
- 同价值或无法估值时，常用代币按 `USDT、USDC、ETH、BTC、BNB、SOL、TRX` 的顺序优先。
- 每行展示代币名称、聚合数量、聚合 USD 价值和持有该代币的网络数量。
- “隐藏零余额”开启时，仅当一个代币在所有网络上的余额都为 0，才隐藏整个代币。
- 某个网络查询失败时保留该代币的其他有效网络，并显示“部分网络数据异常”。

### 2.2 代币详情

- 顶部展示代币聚合数量、USD 总价值和网络数量。
- 网络列表展示链名称、链上数量、该网络 USD 价值及错误状态。
- 点击具体网络进入现有的单链、单合约交易记录页。
- 首版不增加用户自定义首页排序、收藏和拖拽能力。

### 2.3 代币身份安全

禁止仅按 symbol 合并资产。内置资产通过 `chainId + contractAddress/native` 解析到可信的 `canonicalTokenId`：

- `USDT`、`USDC`：只聚合内置注册表中已知的官方合约。
- `ETH`：聚合 Ethereum、Arbitrum 原生 ETH 及内置的受信任映射。
- `BTC`：内置 BTCB、WBTC 映射为统一 BTC 组合。
- `BNB`、`SOL`、`TRX`：聚合对应原生资产。
- 未登记或用户自定义资产使用链和合约生成隔离 ID，即使 symbol 相同也不会并入常用代币。
- 未登记资产不按 symbol 套用内置行情价格，避免同名自定义币制造虚假 USD 估值。

## 3. 技术设计

### 3.1 展示模型

新增只用于组合展示的模型，不修改链上余额原始模型：

```text
TokenPortfolioItem
  canonicalTokenId
  symbol / name / logoUrl
  positions: List<TokenChainPosition>
  totalAmount
  totalUsdValue
  hasPartialError

TokenChainPosition
  balance: ChainBalance
  chain: WalletChainConfig
  usdValue
```

`ChainBalance` 仍是转账、交易记录和缓存使用的准确链上资产实体。聚合模型只在内存中从余额派生，因此不需要本地数据迁移。

### 3.2 组件结构

```text
HomePage
  WalletOverviewCard
  AssetFilterBar
  TokenPortfolioSection
    TokenPortfolioCard × N

TokenPortfolioDetailPage
  TokenPortfolioSummaryCard
  TokenChainPositionCard × N
```

首页列表和详情列表采用小组件组合、语义标签、动态字体兼容和现有 `ScreenUtil` 尺寸体系。动画只使用现有轻量进入动画和隐式动画，避免额外布局抖动。

### 3.3 Controller 与导航

- `HomeController` 从 `visibleBalances` 和价格缓存派生 `tokenPortfolioItems`。
- 钱包切换、余额刷新、可见性变化和价格刷新后统一重算组合。
- 首页点击组合时，将不可变的 `TokenPortfolioItem` 作为详情页参数。
- 详情页点击网络资产时，将原始 `ChainBalance` 传给现有 `TransactionHistoryPageArguments`。

## 4. 实施步骤

1. 增加可信代币目录、身份解析器和组合模型。
2. 为聚合数量、估值、排序、零余额和异常状态增加纯逻辑测试。
3. 改造 `HomeController`，生成首页组合状态。
4. 新增首页代币列表，替换现有 `ChainSection` 入口。
5. 新增代币多链详情页及 GetX 路由。
6. 接入现有交易记录页。
7. 增加中英文文案并重新生成国际化和路由文件。
8. 执行格式化、静态分析和完整测试。

## 5. 验收标准

- 同一可信代币跨链余额和 USD 价值汇总正确。
- 自定义同名代币不会并入内置代币。
- 隐藏资产和隐藏零余额规则在聚合后仍然正确。
- 单链失败不会抹掉其他链已有余额，并有局部错误提示。
- 切换钱包或刷新时不会短暂显示上一个钱包的组合数据。
- 首页代币可进入多链详情，网络资产可进入对应交易记录。
- 中英文、明暗主题、动态字体和屏幕阅读语义可用。
- 新增逻辑有单元测试，改造不新增静态分析错误。

## 6. 工作量与边界

预计 4～6 人天，包括约 6～10 个新增文件、8～12 个修改文件、国际化/路由生成文件和测试。若后续增加用户收藏、拖拽排序、远端代币目录或跨钱包组合，需要单独设计持久化和同步能力。
