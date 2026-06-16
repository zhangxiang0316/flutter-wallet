# Phase 3 WalletConnect 集成实施指南

## ✅ 已完成（Phase 1 + 2 + 依赖）

### Phase 1: 转账安全基础
- ✅ `lib/utils/transaction_risk_checker.dart` - 风险检测工具
- ✅ `lib/widget/transaction_review_sheet.dart` - 交易审查组件
- ✅ `lib/page/transfer/view/widgets/transfer_form_panel.dart` - 改造转账流程

### Phase 2: 消息签名功能
- ✅ `lib/widget/message_sign_sheet.dart` - 消息签名界面
- ✅ `lib/wallet/services/wallet_transfer_service.dart` - 扩展签名方法
  - signPersonalMessage() - EIP-191
  - signTypedData() - EIP-712
  - signSolanaMessage() - Solana
  - signTronMessage() - TRON

### 入口 + SDK
- ✅ `lib/page/home/view/home_page.dart` - 添加扫码按钮
- ✅ `pubspec.yaml` - 添加 reown_walletkit: ^1.1.2

---

## 🚧 待实现（Phase 3 剩余工作）

### 1. WalletConnect 服务（核心）
**文件**: `lib/wallet/services/walletconnect_service.dart`

```dart
class WalletConnectService {
  ReownWalletKit? _walletKit;
  
  Future<void> initialize() async {
    // 初始化 WalletConnect
    // projectId: 从 WalletConnect Cloud 获取
  }
  
  Future<void> pair(String uri) async {
    // 通过扫码 URI 配对
  }
  
  List<SessionData> getActiveSessions() {
    // 获取所有活动会话
  }
  
  Future<void> disconnect(String topic) async {
    // 断开指定会话
  }
  
  Stream<SessionProposalEvent> get onSessionProposal;
  Stream<SessionRequestEvent> get onSessionRequest;
  Stream<SessionDeleteEvent> get onSessionDelete;
}
```

### 2. 扫码页面
**文件**: `lib/page/dapp/view/dapp_scanner_page.dart`

复用现有的 `TransferAddressScannerPage` 作为参考：
- 使用 `mobile_scanner` 包
- 检测 `wc:` 开头的 URI
- 调用 `WalletConnectService.pair(uri)`

### 3. 连接请求确认界面
**文件**: `lib/page/dapp/view/connection_request_sheet.dart`

```dart
class ConnectionRequestSheet extends StatelessWidget {
  final SessionProposal proposal;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  
  // 显示:
  // - DApp 图标、名称、URL
  // - 请求的链（Ethereum, BSC, etc.）
  // - 当前钱包地址
  // - 权限说明
  // - Reject / Connect 按钮
}
```

### 4. DApp 请求路由器
**文件**: `lib/page/dapp/services/dapp_request_router.dart`

```dart
class DAppRequestRouter {
  Future<dynamic> handleRequest(SessionRequest request) {
    switch (request.method) {
      case 'eth_sendTransaction':
        return _handleSendTransaction(request);
      case 'personal_sign':
        return _handlePersonalSign(request);
      case 'eth_signTypedData_v4':
        return _handleSignTypedData(request);
      case 'wallet_switchEthereumChain':
        return _handleSwitchChain(request);
      default:
        throw UnsupportedMethodException(request.method);
    }
  }
  
  Future<String> _handleSendTransaction(SessionRequest request) async {
    // 1. 解析交易参数
    // 2. 显示 TransactionReviewSheet（复用 Phase 1）
    // 3. 用户批准后显示密码
    // 4. 签名并广播
    // 5. 返回交易哈希
  }
  
  Future<String> _handlePersonalSign(SessionRequest request) async {
    // 1. 解析消息
    // 2. 显示 MessageSignSheet（复用 Phase 2）
    // 3. 用户批准后显示密码
    // 4. 调用 signPersonalMessage()
    // 5. 返回签名
  }
}
```

### 5. WalletConnect 控制器
**文件**: `lib/page/dapp/controller/walletconnect_controller.dart`

```dart
class WalletConnectController extends BaseController {
  final WalletConnectService _wcService;
  
  @override
  void onInit() {
    super.onInit();
    _wcService.initialize();
    _listenToEvents();
  }
  
  void _listenToEvents() {
    // 监听连接请求
    _wcService.onSessionProposal.listen((proposal) {
      _showConnectionRequest(proposal);
    });
    
    // 监听交易/签名请求
    _wcService.onSessionRequest.listen((request) {
      DAppRequestRouter().handleRequest(request);
    });
  }
  
  Future<void> scanAndConnect() async {
    // 打开扫码页面
  }
}
```

### 6. 已连接 DApp 管理页面
**文件**: `lib/page/dapp/view/connected_dapps_page.dart`

```dart
class ConnectedDAppsPage extends BaseScaffoldPage {
  // 显示所有已连接的 DApp 列表
  // 每项显示：图标、名称、连接时间、网络
  // 点击进入详情：显示权限、断开连接按钮
  // 支持批量断开
}
```

### 7. 路由配置
**文件**: 需要在路由中添加

```dart
@GetXRoutePage('/dapp/scan')
class DAppScannerPage extends BasePage {}

@GetXRoutePage('/dapp/connected')
class ConnectedDAppsPage extends BasePage {}
```

### 8. 更新首页扫码方法
**文件**: `lib/page/home/view/home_page.dart`

```dart
void _scanToConnectDApp() async {
  if (controller.wallet == null) {
    Toast.show('Please create a wallet first');
    return;
  }
  
  // 取消注释，打开扫码页面
  await Get.toNamed(RouteTable.dappScan);
}
```

---

## 📋 实施步骤建议

### Day 1: 核心服务
1. 实现 `WalletConnectService` (2-3小时)
2. 实现 `WalletConnectController` (1-2小时)
3. 测试初始化和配对 (1小时)

### Day 2: UI 和交互
1. 创建扫码页面 (1小时)
2. 创建连接请求确认界面 (2小时)
3. 实现 `DAppRequestRouter` (2-3小时)
4. 测试连接流程 (1小时)

### Day 3: 管理和优化
1. 创建 DApp 管理页面 (2小时)
2. 会话持久化 (1小时)
3. 错误处理和边界情况 (2小时)
4. 完整测试和优化 (2小时)

---

## 🔑 关键技术点

### 1. WalletConnect URI 格式
```
wc:xxx@2?relay-protocol=irn&symKey=xxx
```

### 2. 会话提案响应
```dart
await _walletKit.approveSession(
  id: proposal.id,
  namespaces: {
    'eip155': SessionNamespace(
      chains: ['eip155:1', 'eip155:56'],  // Ethereum, BSC
      methods: ['eth_sendTransaction', 'personal_sign', 'eth_signTypedData_v4'],
      events: ['chainChanged', 'accountsChanged'],
      accounts: ['eip155:1:0xYourAddress', 'eip155:56:0xYourAddress'],
    ),
  },
);
```

### 3. 请求响应
```dart
await _walletKit.respondSessionRequest(
  topic: request.topic,
  response: JsonRpcResponse(
    id: request.id,
    result: signatureOrTxHash,
  ),
);
```

---

## 🧪 测试 DApp

可以使用以下测试 DApp：
1. **WalletConnect 官方测试 DApp**: https://react-app.walletconnect.com/
2. **Uniswap**: https://app.uniswap.org/
3. **OpenSea**: https://opensea.io/

---

## 📚 参考文档

- WalletConnect v2 规范: https://docs.walletconnect.com/
- Reown WalletKit 文档: https://docs.reown.com/walletkit/overview
- EIP-191: https://eips.ethereum.org/EIPS/eip-191
- EIP-712: https://eips.ethereum.org/EIPS/eip-712

