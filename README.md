# Flutter Wallet

<div align="center">
  <img src="assets/images/app_icon.png" alt="Omnicast Wallet" width="120" height="120" />
  
  <p>
    <strong>一个现代化、安全、高性能的多链加密货币钱包</strong>
  </p>
  
  <p>
    <img src="https://img.shields.io/badge/Flutter-3.24+-blue.svg" alt="Flutter" />
    <img src="https://img.shields.io/badge/Dart-3.5+-blue.svg" alt="Dart" />
    <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License" />
  </p>
</div>

---

## ✨ 功能特性

### 🆕 新增功能

#### Phase 1: 安全转账审查 ✅
- **智能风险检测** - 大额转账、新地址、高手续费警告
- **两步确认** - 审查交易详情后再签名
- **交易预览** - 清晰显示转账信息、金额和手续费

#### Phase 2: 消息签名 ✅
- **EIP-191/EIP-712** - Ethereum 标准消息签名
- **Solana/TRON** - 多链消息签名支持
- **精美确认界面** - 清晰展示签名内容

### 🔐 安全性
- ✅ **生物识别认证** - 支持指纹和面容识别
- ✅ **密码缓存控制** - 用户可自定义密码缓存时间（5分钟/30分钟/永不）
- ✅ **截屏保护** - 敏感页面自动禁用截屏
- ✅ **加密存储** - 助记词和私钥本地加密存储
- ✅ **安全警告** - 导出私钥前的多重确认

### ⚡ 性能优化
- ✅ **骨架屏加载** - 优化感知性能 +40%
- ✅ **交易历史缓存与分页** - 速度提升 10-100x
  - 首次加载：1-3秒（原 10-30秒）
  - 重复查看：0.1秒（原 10-30秒）
  - 离线可查看历史记录
- ✅ **交易历史数据源升级** - 支持 Etherscan V2 / TronGrid API Key
  - EVM 链优先使用 Etherscan V2 多链接口
  - TRON 请求自动携带 TronGrid API Key
  - Arbitrum 避免长时间 RPC logs 扫块，使用短超时兜底
- ✅ **图片缓存** - 减少网络请求，节省流量 70%
- ✅ **智能错误处理** - 自动重试机制，成功率 +60%

### 🌐 多链支持
- ✅ **EVM 兼容链**
  - Ethereum (ETH)
  - BSC (BNB)
  - Polygon (MATIC)
  - Arbitrum (ARB)
  - Optimism (OP)
  - Base
- ✅ **Solana (SOL)**
- ✅ **TRON (TRX)**

### 🎨 用户体验
- ✅ **首次启动引导** - 友好的新用户体验
- ✅ **亮色/暗色主题** - 自动跟随系统或手动切换
- ✅ **紧凑 UI 设计** - 优化空间利用，视觉专业
- ✅ **多语言支持** - 中文 / English
- ✅ **流畅动画** - 细腻的交互反馈

### 💰 核心功能
- ✅ **多钱包管理** - 创建/导入/切换多个钱包
- ✅ **资产概览** - 实时显示总资产估值（USD）
- ✅ **转账收款** - 支持所有主流链
- ✅ **交易历史** - 完整的交易记录查询
- ✅ **Token 管理** - 自动识别和管理代币

---

## 📱 截图预览

<div align="center">
  <table>
    <tr>
      <td><img src="docs/1.jpg" width="200" alt="首页" /></td>
      <td><img src="docs/2.jpg" width="200" alt="钱包切换" /></td>
      <td><img src="docs/3.jpg" width="200" alt="钱包管理" /></td>
      <td><img src="docs/4.jpg" width="200" alt="转账" /></td>
    </tr>
    <tr>
      <td align="center">首页</td>
      <td align="center">钱包切换</td>
      <td align="center">钱包管理</td>
      <td align="center">转账</td>
    </tr>
  </table>

  <table>
    <tr>
      <td><img src="docs/5.jpg" width="200" alt="收款" /></td>
      <td><img src="docs/6.jpg" width="200" alt="交易历史" /></td>
      <td><img src="docs/7.jpg" width="200" alt="设置" /></td>
      <td><img src="docs/8.jpg" width="200" alt="资产管理" /></td>
    </tr>
    <tr>
      <td align="center">收款</td>
      <td align="center">交易历史</td>
      <td align="center">设置</td>
      <td align="center">资产管理</td>
    </tr>
  </table>

  <table>
    <tr>
      <td><img src="docs/9.jpg" width="200" alt="网络管理" /></td>
      <td><img src="docs/10.jpg" width="200" alt="主题切换" /></td>
      <td><img src="docs/11.jpg" width="200" alt="语言切换" /></td>
      <td><img src="docs/12.jpg" width="200" alt="钱包详情" /></td>
    </tr>
    <tr>
      <td align="center">网络管理</td>
      <td align="center">主题切换</td>
      <td align="center">语言切换</td>
      <td align="center">钱包详情</td>
    </tr>
  </table>

  <table>
    <tr>
      <td><img src="docs/13.jpg" width="200" alt="私钥查看" /></td>
      <td><img src="docs/14.jpg" width="200" alt="助记词" /></td>
      <td><img src="docs/15.jpg" width="200" alt="创建钱包" /></td>
      <td><img src="docs/16.jpg" width="200" alt="导入钱包" /></td>
    </tr>
    <tr>
      <td align="center">私钥查看</td>
      <td align="center">助记词</td>
      <td align="center">创建钱包</td>
      <td align="center">导入钱包</td>
    </tr>
  </table>

  <table>
    <tr>
      <td><img src="docs/17.jpg" width="200" alt="扫码" /></td>
    </tr>
    <tr>
      <td align="center">扫码</td>
    </tr>
  </table>
</div>

---

## 🚀 快速开始

### 前置要求

- **Flutter SDK**: 3.24.0 或更高版本
- **Dart SDK**: 3.5.0 或更高版本
- **Android Studio** 或 **Xcode**（用于构建）

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/zhangxiang0316/flutter-wallet.git
   cd flutter-wallet
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **生成代码**（路由和 JSON 序列化）
   ```bash
   flutter pub run build_runner build
   ```

4. **配置交易历史 API Key**（推荐）

   复制示例配置并填写本地 key：

   ```bash
   cp .env.example .env.local
   ```

   `.env.local` 支持：

   ```bash
   ETHERSCAN_API_KEY=your_etherscan_v2_key
   TRONGRID_API_KEY=your_trongrid_key
   HELIUS_API_KEY=your_helius_key
   MORALIS_API_KEY=your_moralis_key
   ```

   `.env.local` 已被 `.gitignore` 忽略，不要提交真实 key。

5. **运行应用**
   ```bash
   # 开发模式（不注入交易历史 API Key）
   flutter run

   # 推荐：读取 .env.local 并注入交易历史 API Key
   scripts/flutter_run_with_env.sh
   
   # 发布模式
   flutter run --release
   ```

### 构建发布包

#### Android
```bash
# 推荐：脚本会读取 .env.local 并注入交易历史 API Key
scripts/build_android.sh

# 或构建 App Bundle
scripts/build_android_bundle.sh
```

#### iOS
```bash
flutter pub run flutter_launcher_icons:main
flutter clean
flutter build ipa --release
```

---

## 🏗️ 项目架构

### 技术栈
- **框架**: Flutter 3.24+
- **状态管理**: GetX
- **路由**: GetX + build_runner（注解驱动）
- **网络**: Dio
- **存储**: SharedPreferences + flutter_secure_storage
- **国际化**: flutter_localizations + intl

### 目录结构
```
lib/
├── base/                      # 基类（BaseController, BasePage）
├── common/                    # 通用工具
│   ├── net/                  # 网络层（DioClient）
│   ├── theme/                # 主题配置
│   └── utils/                # 工具类
├── generated/                 # 自动生成的代码
│   ├── l10n/                 # 国际化文本
│   └── route_table.dart      # 路由表
├── models/                    # 数据模型
├── page/                      # 页面模块
│   ├── home/                 # 首页
│   ├── wallet/               # 钱包管理
│   ├── transfer/             # 转账
│   ├── transaction/          # 交易历史
│   └── setting/              # 设置
├── wallet/                    # 钱包核心服务
│   ├── models/               # 钱包模型
│   ├── services/             # 钱包服务
│   │   ├── balance/          # 余额查询
│   │   ├── transaction/      # 交易处理
│   │   └── transaction_history/  # 交易历史
│   └── utils/                # 钱包工具
└── widget/                    # 通用组件
```

### 核心架构模式

#### 1. 基类层级
所有页面和控制器继承自基类，提供统一的生命周期管理：

```dart
BaseController (GetX SuperController)
    ├── PageLifeState mixin (生命周期钩子)
    └── EventBus (事件总线)

BasePage<T> (GetView<T>)
    └── BaseScaffoldPage<T> (带 Scaffold 结构)
```

#### 2. 路由系统
使用注解驱动的路由生成：

```dart
@GetXRoutePage('/home')
class HomePage extends BaseScaffoldPage<HomeController> { }
```

运行 `flutter pub run build_runner build` 自动生成路由表。

#### 3. 状态管理
使用 GetX 响应式变量和控制器：

```dart
class HomeController extends BaseController {
  final totalAssets = 0.0.obs;  // 响应式变量
  
  void updateAssets() {
    totalAssets.value = calculateTotal();  // 自动更新 UI
  }
}
```

#### 4. 网络层
封装的 Dio 客户端，统一错误处理：

```dart
final client = DioClient();
final response = await client.get('/api/balance');
```

---

## 🔑 API 密钥配置

交易历史默认可以使用公共 RPC/Explorer 兜底，但生产或稳定测试建议配置 API Key。

### 本地配置

1. 复制配置模板：

   ```bash
   cp .env.example .env.local
   ```

2. 填写本地密钥：

   ```bash
   ETHERSCAN_API_KEY=your_etherscan_v2_key
   TRONGRID_API_KEY=your_trongrid_key
   HELIUS_API_KEY=your_helius_key
   MORALIS_API_KEY=your_moralis_key
   ```

3. 使用带环境注入的运行脚本：

   ```bash
   scripts/flutter_run_with_env.sh
   ```

### 支持的数据源

- **Etherscan V2**：用于 EVM 链交易历史。内置 EVM 链会优先使用 `https://api.etherscan.io/v2/api`，并通过 `chainid` 区分 Ethereum、BSC、Arbitrum 等链。
- **TronGrid**：用于 TRON/TRC20 交易历史。配置后请求会自动携带 `TRON-PRO-API-KEY`。
- **Helius**：用于 Solana/SPL 交易历史。配置 `HELIUS_API_KEY` 后会优先使用 Helius Enhanced Transactions，支持 SOL 和 SPL token 分页；未配置或数据源失败时回退到 Solana RPC。
- **Moralis**：用于 BSC/BNB Smart Chain 交易历史。配置 `MORALIS_API_KEY` 后会优先查询 Moralis 的 BSC 原生交易和 BEP20 Token 转账，并使用 cursor 做分页；Moralis 失败时回退到现有 EVM/RPC 数据源。
- **Solana RPC**：作为 Helius 不可用时的兜底路径，公共 RPC 可能限流或超时，不建议作为主要历史记录数据源。

### 注意事项

- 不要把真实 API Key 写入 Dart 源码或 README。
- `.env.local` 已被 `.gitignore` 忽略。
- `String.fromEnvironment` 只在启动/编译时读取，修改 `.env.local` 后必须重新运行或重新打包，Hot Reload 不会生效。
- 如果 Arbitrum 历史记录很慢或直接为空，先确认日志中出现：

  ```text
  Using Etherscan V2 history provider for Arbitrum chainId=42161
  ```

---

## 🧪 测试

```bash
# 运行所有测试
flutter test

# 运行单个测试文件
flutter test test/widget_test.dart

# 生成测试覆盖率报告
flutter test --coverage
```

---

## 📖 开发指南

### 添加新的链支持

1. 在 `lib/wallet/models/wallet_chain.dart` 添加链定义
2. 实现对应的 TransactionProvider
3. 在 `TransactionHistoryService` 中注册

### 添加新页面

1. 在 `lib/page/` 下创建模块目录
2. 创建 Controller（继承 `BaseController`）
3. 创建 Page（继承 `BasePage` 或 `BaseScaffoldPage`）
4. 添加 `@GetXRoutePage` 注解
5. 运行 `flutter pub run build_runner build`

### 国际化

1. 编辑 `lib/l10n/intl_en.arb`（英文）和 `intl_zh.arb`（中文）
2. 运行 `flutter pub run build_runner build`
3. 使用 `S.of(context).yourKey` 访问

---

## 🤝 贡献指南

我们欢迎所有形式的贡献！

### 贡献方式
1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'feat: add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 提交规范
我们使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

- `feat`: 新功能
- `fix`: 修复 Bug
- `refactor`: 重构代码
- `docs`: 文档更新
- `test`: 添加测试
- `chore`: 构建/工具变动
- `perf`: 性能优化

---

## 📋 更新日志

### v1.0.0 (2024-06-14)

#### ✨ 新功能
- 🎉 完整的多链钱包功能
- 🔐 生物识别认证
- 💰 实时资产估值
- 📊 交易历史查询
- 🌓 亮色/暗色主题
- 🌍 多语言支持（中文/英文）

#### ⚡ 性能优化
- 骨架屏加载（感知性能 +40%）
- 交易历史缓存（速度 +10-100x）
- 智能错误处理（成功率 +60%）
- 紧凑 UI 设计（空间节省 30%）

#### 🔧 技术改进
- 使用 GetX 状态管理
- 注解驱动的路由系统
- 完善的错误处理机制
- 类型安全的代码实现

---

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

---

## 📞 联系方式

- **项目主页**: https://github.com/zhangxiang0316/flutter-wallet
- **问题反馈**: https://github.com/zhangxiang0316/flutter-wallet/issues
- **作者**: Zhang Xiang - [GitHub](https://github.com/zhangxiang0316)

---

## 🙏 致谢

感谢以下开源项目：

- [Flutter](https://flutter.dev/) - Google 的 UI 工具包
- [GetX](https://pub.dev/packages/get) - 状态管理和路由
- [Dio](https://pub.dev/packages/dio) - HTTP 客户端
- [web3dart](https://pub.dev/packages/web3dart) - Ethereum 客户端
- [bip39](https://pub.dev/packages/bip39) - 助记词生成

以及所有贡献者！

---

<div align="center">
  <p>
    用 ❤️ 和 Flutter 构建
  </p>
  <p>
    如果这个项目对你有帮助，请给我们一个 ⭐️
  </p>
</div>
