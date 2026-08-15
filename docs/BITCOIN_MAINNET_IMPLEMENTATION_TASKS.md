# Bitcoin Mainnet 接入任务

## 1. 首版范围

首版接入 Bitcoin Mainnet 原生 BTC，采用 BIP84 路径
`m/84'/0'/0'/0/0` 和 Native SegWit（P2WPKH，`bc1q...`）地址。

包含：

- 创建、助记词导入和私钥导入时生成 BTC 地址；
- 已有钱包解锁后补全 BTC 地址；
- BTC 余额、USD 估值、首页 BTC 聚合和收款二维码；
- BTC 链上交易记录、确认状态和区块浏览器；
- P2WPKH UTXO 转账、动态手续费、找零、签名和广播。

首版不包含 Lightning、Taproot、Ordinals、BRC-20、多签、RBF/CPFP 和测试网。

## 2. 实施任务

### T1：链模型与原生资产

- [x] 增加 `WalletChain.bitcoin` 和 `WalletChainType.bitcoin`。
- [x] 增加链类型判断、品牌色、浏览器和 API 配置。
- [x] 注册原生 BTC 资产（8 位精度、`canonicalTokenId=btc`）。
- [x] BTC 资产设置仅允许显示/隐藏，不显示“添加合约代币”。

验收：BTC 出现在启用网络和资产配置中，不会被识别为 EVM 网络。

### T2：密钥、地址与钱包兼容

- [x] 增加 BIP84 派生路径和 P2WPKH Bech32 地址编码。
- [x] `WalletKeyPair`、`WalletAccount` 增加 `bitcoinAddress`。
- [x] 创建、助记词导入、私钥导入时保存 BTC 地址。
- [x] 增加 BTC 签名私钥读取方法。
- [x] 增加已有钱包 BTC 地址补全流程。

验收：使用公开 BIP84 测试向量验证地址；旧钱包不丢失原有地址和密钥。

### T3：余额、行情与只读页面

- [x] 新增 Bitcoin REST/Esplora 余额提供器和备用节点。
- [x] 首页余额请求携带 `bitcoinAddress`。
- [x] 增加 BTC 行情映射和缓存测试。
- [x] 原生 BTC 与 BTCB/WBTC 聚合到同一 BTC 首页卡片。
- [x] 收款页、钱包详情和钱包切换器展示 BTC 地址。

验收：在线、空地址、零余额、接口失败和缓存场景展示正确。

### T4：交易记录与状态

- [x] 新增 Bitcoin 交易记录提供器和分页游标。
- [x] 根据 inputs/outputs 判断收款、转出、金额和手续费。
- [x] 增加未确认/已确认状态查询。
- [x] 增加 BTC 地址和交易浏览器链接。

验收：收款、转出、自转、未确认和分页数据解析正确。

### T5：BTC 转账

- [x] 查询并筛选可花费 UTXO。
- [x] 获取动态 sat/vB 费率并估算虚拟大小。
- [x] 实现选币、dust 处理和找零。
- [x] 构造并签名 P2WPKH 交易。
- [x] 广播原始交易并保存本地 pending 记录。
- [x] 增加 BTC 地址/BIP21 扫码解析和转账确认信息。

验收：固定测试向量的交易序列化和签名一致；金额、手续费、找零守恒；禁止超额和 dust 转账。

### T6：质量检查

- [x] 补齐中英文文案并同步国际化代码。
- [x] 增加密钥、地址、余额、历史、转账、迁移和 UI 测试。
- [ ] 执行格式化、静态分析、相关测试和完整回归。
- [ ] Android 真机验证创建、升级、余额、收款和转账流程。

当前自动验证结果：

- `flutter analyze`：无新增 error；仓库仍有 46 条既有 info 级提示。
- BTC 相关测试：109 个通过。
- `flutter build apk --debug`：通过。
- 完整测试：220 个中 218 个通过；两个失败均位于既有
  `transaction_history_cache_test.dart`，单独运行仍可复现，与 BTC 改造无关。

## 3. 实施顺序与安全门槛

先完成 T1～T4 并验收只读能力，再开始 T5。BTC 转账只有在以下条件全部满足后才开放入口：

1. 地址派生通过公开测试向量；
2. 交易签名和序列化通过固定向量；
3. UTXO 金额等于转账金额、手续费与找零之和；
4. 接口异常不会重复广播；
5. Android 真机小额测试通过。
