# Aptos Mainnet 接入任务

## 1. 目标与首版范围

在现有 EVM、Solana、TRON、Bitcoin、Sui 多链钱包中新增 Aptos Mainnet，继续沿用首页
“按代币聚合、进入后查看各链余额”的交互。

首版包含：

- 创建钱包、助记词导入和私钥导入时生成 Aptos Ed25519 地址；
- 已有钱包解锁后补全 Aptos 地址；
- APT 和 Circle 原生 USDC 的余额、价格与首页聚合；
- APT、USDC 收款、手续费模拟、签名和广播；
- Aptos 交易记录、执行状态和 Explorer 跳转；
- Android/iOS 共用的纯 Dart 实现与回归测试。

首版不包含 Keyless、MultiKey、多签、Sponsored Transaction、NFT、Token v1/v2、
自定义 Move 调用和自定义 Fungible Asset。

## 2. 已确认的协议与数据

- 网络：Aptos Mainnet，chain id 为 `1`，Fullnode REST 为
  `https://api.mainnet.aptoslabs.com/v1`。
- 密钥：Legacy Ed25519，SLIP-0010 路径 `m/44'/637'/0'/0'/0'`。
- 地址：Ed25519 公钥和 scheme byte `0x00` 计算 SHA3-256 authentication key。
- APT：8 位精度，链上资产标识 `0x1::aptos_coin::AptosCoin`。
- Circle USDC：6 位精度，Fungible Asset metadata 地址为
  `0xbae207659db88bea0cbead6da0ed00aac12edcdda169e591cd41c94180b46f3b`。
- APT 转账调用 `0x1::aptos_account::transfer`。
- USDC 转账调用 `0x1::primary_fungible_store::transfer`，参数为 metadata、收款地址、
  最小单位金额。
- 交易必须先读取 sequence number、gas price 和 ledger chain id，再 BCS 编码、模拟、
  Ed25519 签名并提交。

协议参考：

- [Aptos Developer Documentation](https://aptos.dev/)
- [Aptos Mainnet Fullnode API](https://api.mainnet.aptoslabs.com/v1/spec)
- [Circle USDC Contract Addresses](https://developers.circle.com/stablecoins/usdc-contract-addresses)
- [Circle Aptos USDC Transfer Quickstart](https://developers.circle.com/stablecoins/quickstart-setup-transfer-usdc-aptos)

## 3. 实施任务

### T1：链模型与资产注册

- [x] 增加 `WalletChain.aptos`、`WalletChainType.aptos` 和 `isAptos`。
- [x] 增加 Aptos RPC、chain id、品牌色和 Explorer 配置。
- [x] 注册 APT（8 位精度，`canonicalTokenId=apt`）。
- [x] 注册 Aptos USDC（6 位精度，`canonicalTokenId=usdc`）。
- [x] 把 Aptos 纳入启用网络、价格查询和首页代币聚合。

### T2：密钥、地址和旧钱包迁移

- [x] 增加 Aptos SLIP-0010 Ed25519 派生及地址生成。
- [x] `WalletKeyPair`、`WalletAccount` 增加 `aptosAddress`。
- [x] 创建、助记词导入、私钥导入时保存 Aptos 地址。
- [x] 增加 Aptos 签名私钥读取方法。
- [x] 已有钱包解锁时补全 Aptos 地址。

### T3：余额、行情与只读页面

- [x] 通过官方 Fullnode REST 查询 APT 与 Aptos USDC 余额。
- [x] 首页余额请求携带 `aptosAddress`。
- [x] 增加 APT 行情映射，并把 Aptos USDC 合并到 USDC 聚合卡片。
- [x] 收款页、钱包详情、钱包选择器展示 Aptos 地址。
- [x] RPC 健康检查验证 Aptos chain id。

### T4：交易历史、状态与浏览器

- [x] 增加 Aptos 账户交易历史提供器和分页游标。
- [x] 解析 APT/USDC 的存入、转出、金额、gas 和执行状态。
- [x] 增加按 hash 查询 pending/success/failed 状态。
- [x] 增加 Aptos Explorer 地址和交易链接。

### T5：APT 与 USDC 转账

- [x] 校验并标准化 32 字节 Aptos 地址。
- [x] 构造 APT transfer entry function。
- [x] 构造 USDC primary fungible store transfer。
- [x] 模拟交易并展示 APT 手续费预估值。
- [x] Ed25519 签名、提交并保存本地 pending 记录。
- [x] 增加扫码地址识别、自转账和零地址风险提示。

### T6：质量检查

- [x] 补齐中英文文案、链品牌色和标签。
- [x] 增加地址测试向量、模型、聚合、历史、扫码、转账模拟和 Explorer 测试。
- [x] 格式化本次变更的 Dart 文件。
- [x] 执行完整 `flutter test` 和 `flutter analyze`。
- [x] 执行 Android debug APK 构建。
- [ ] 使用 testnet 资金完成 APT/USDC 真机小额转账后再用于 mainnet 资金。

## 4. 安全门槛

1. 助记词派生地址必须和 Aptos SDK 固定向量一致；
2. 发起交易前验证私钥派生地址与资产发送地址一致；
3. 所有金额只使用整数最小单位，不使用浮点数；
4. 模拟失败、余额不足、sequence 冲突或签名失败时不得广播；
5. 网络超时不自动重复提交相同签名交易；
6. 发布前完成 testnet 真机验证。

## 5. 架构策略

Aptos 按新的非 EVM 协议适配器接入，不伪装为自定义 EVM 网络。页面继续复用统一的
`ChainBalance`、交易记录和转账审查模型；密钥、余额、历史和交易构造放在 Aptos 专属
provider 中，减少页面层链分支扩散。

## 6. 实施结果与验证记录

实施日期：2026-08-16。

- 引入纯 Dart `aptos: ^1.0.0` SDK，用于 Ed25519 账户、BCS 交易构造、模拟、签名与
  提交；余额和交易历史分别直接使用 Aptos Fullnode REST 与官方 Indexer GraphQL。
- 使用固定助记词验证 Aptos Legacy BIP44 地址：
  `0xeb663b681209e7087d681c5d3eed12aaa8e1915e7c87794542c3f96e94b3d3bf`。
- 主网只读验证通过：Fullnode 返回 `chain_id=1`，APT 与 Circle USDC 余额端点返回合法
  最小单位结果，Indexer 活动查询及 bigint 分页过滤可用。
- `flutter test`：243 项全部通过。
- `flutter analyze`：无 error；仍有 46 条仓库既有 info 级提示，本次未扩大范围处理。
- `flutter build apk --debug`：成功，产物位于
  `build/app/outputs/flutter-apk/app-debug.apk`。
- 尚未执行需要测试资金和外部广播的 testnet APT/USDC 真机小额转账，因此生产主网
  转账上线前仍必须完成最后一项安全门槛。
