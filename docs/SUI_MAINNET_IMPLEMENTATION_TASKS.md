# Sui Mainnet 接入任务

## 1. 目标与首版范围

在现有 EVM、Solana、TRON、Bitcoin 多链钱包基础上接入 Sui Mainnet，保持首页
“按代币聚合、进入后查看各链余额”的交互方式。

首版包含：

- 创建钱包、助记词导入和私钥导入时生成 Sui 地址；
- 已有钱包在解锁后补全 Sui 地址；
- SUI 原生资产和 Sui 原生 USDC 的余额、USD 估值及首页聚合；
- SUI、USDC 收款、转账、手续费预估和交易广播；
- Sui 链交易记录、交易状态和区块浏览器跳转；
- Android/iOS 共用的本地签名实现与单元测试。

首版不包含 zkLogin、多签、硬件钱包、赞助交易、NFT、Kiosk、DeepBook、CCTP
跨链和自定义 Move 调用。

## 2. 技术约束

- 密钥方案使用 Ed25519，派生路径为 `m/44'/784'/0'/0'/0'`。
- 地址按 Sui 规则由“签名方案标识 + 公钥”做 Blake2b-256 后生成 32 字节地址。
- 数据访问优先使用 Sui gRPC；需要复杂历史查询时使用 GraphQL。
- 不以已经弃用的 Sui JSON-RPC 作为新功能依赖。
- SUI 和 USDC 转账必须处理 Sui 的 Coin Object、gas coin、Programmable
  Transaction Block 和 BCS 序列化，不能复用 EVM 转账构造器。
- Sui 原生 USDC 类型固定为
  `0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC`。
- 金额一律先转换为最小单位整数再参与交易构造，禁止使用浮点数。

## 3. 实施任务

### T1：链模型与资产注册

- [x] 增加 `WalletChain.sui` 和 `WalletChainType.sui`。
- [x] 增加链类型判断、品牌色、RPC 和区块浏览器配置。
- [x] 注册 SUI 原生资产（9 位精度，`canonicalTokenId=sui`）。
- [x] 注册 Sui USDC（6 位精度，`canonicalTokenId=usdc`）。
- [x] 将 Sui 纳入启用网络、资产设置和首页代币聚合。

验收：SUI 和 USDC/Sui 能由数据驱动出现在首页，不会被识别为 EVM 网络。

### T2：密钥、地址与旧钱包兼容

- [x] 增加 Sui SLIP-0010 Ed25519 私钥派生和地址编码。
- [x] `WalletKeyPair`、`WalletAccount` 增加 `suiAddress`。
- [x] 创建、助记词导入、私钥导入时保存 Sui 地址。
- [x] 增加 Sui 签名私钥读取方法。
- [x] 增加已有钱包 Sui 地址补全流程。

验收：公开测试向量的地址派生结果一致；旧钱包升级后原有地址和密钥不变。

### T3：余额、估值与只读页面

- [x] 新增 Sui gRPC 余额提供器，RPC 地址跟随内置链配置。
- [x] 查询 SUI、Sui USDC 的余额和精度。
- [x] 首页余额请求携带 `suiAddress`。
- [x] 增加 SUI 行情映射，并把 Sui USDC 聚合到首页 USDC 卡片。
- [x] 收款页、钱包详情和钱包切换器展示 Sui 地址。

验收：在线、空地址、零余额、接口失败和缓存场景展示正确。

### T4：交易记录与状态

- [x] 新增 Sui GraphQL/索引服务交易记录提供器和分页游标。
- [x] 根据 Balance Changes 判断收款、转出、币种、金额和手续费。
- [x] 增加交易执行状态查询。
- [x] 增加 Sui 地址和交易浏览器链接。

验收：SUI/USDC 收款、转出、失败交易和分页数据解析正确。

### T5：SUI 与 USDC 转账

- [x] 查询并选择 SUI Coin Object 和 gas coin。
- [x] 构造 SUI `splitCoins + transferObjects` 交易。
- [x] 构造 USDC Coin Object 合并、拆分和转账交易。
- [x] dry-run/估算 gas budget，展示用户支付的 SUI 手续费。
- [x] 使用 Ed25519 对 intent message 签名并广播交易。
- [x] 保存本地 pending 记录，防止重复提交。
- [x] 增加 Sui 地址和扫码 URI 校验。

验收：金额、gas 和对象输入一致；余额不足、gas 不足、对象冲突和广播失败时不会误报成功。

### T6：质量检查

- [x] 补齐中英文文案、品牌色和链标签。
- [x] 增加密钥、地址、模型、聚合、历史、扫码和浏览器测试。
- [x] 对本次变更的 Dart 文件执行 `dart format`。
- [x] 执行 `flutter analyze` 和完整 `flutter test`。
- [x] 执行 Android debug 构建。
- [ ] 在 Sui testnet 完成小额 SUI/USDC 真机验证后再开放 mainnet 转账。

自动化验证结果（2026-08-15）：完整测试套件 232 项通过；静态分析无 error，
保留项目原有 46 条 info；Android debug APK 构建成功。真实网络的小额转账仍需使用
测试资金和真机完成，不能由纯本地自动化替代。

## 4. 实施顺序与安全门槛

实施顺序为 T1 → T2 → T3 → T4 → T5 → T6。只读能力完成并通过测试之后，才合入
转账实现；生产发布前仍需完成 testnet 真机验证。

Sui 转账需要同时满足以下条件：

1. 地址派生通过固定测试向量；
2. BCS 交易序列化和 intent 签名通过固定测试向量；
3. dry-run 返回成功且 gas budget 足够；
4. Coin Object 选择不会重复消费 gas object；
5. 接口超时和重试不会重复广播；
6. testnet 真机小额 SUI、USDC 转账验证通过。

## 5. 架构方向

Sui 作为新的协议适配器接入，不把非 EVM 链伪装成可配置 EVM 网络。后续应逐步把
`balance`、`transfer`、`history`、`address validation` 和 `explorer` 的链分支收敛到
统一的非 EVM 适配器接口。这样将来接入 Aptos、Stellar 或 TON 时，只新增协议实现，
避免继续扩大页面和核心 service 中的 `switch`。
