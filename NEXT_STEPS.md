# DApp 扫码授权功能 - 下一步工作

## ✅ 已完成 (85%)

### Phase 1: 转账安全基础 (100%)
- ✅ TransactionReviewSheet - 交易审查组件
- ✅ TransactionRiskChecker - 风险检测工具
- ✅ 改造转账流程 - 两步确认

### Phase 2: 消息签名功能 (100%)
- ✅ MessageSignSheet - 消息签名界面
- ✅ signPersonalMessage() - EIP-191
- ✅ signTypedData() - EIP-712
- ✅ signSolanaMessage() - Solana
- ✅ signTronMessage() - TRON

### Phase 3: WalletConnect 集成 (85%)
- ✅ WalletConnectService - 核心服务
- ✅ DAppScannerPage - 扫码页面
- ✅ ConnectionRequestSheet - 连接确认
- ✅ 首页扫码按钮
- ✅ SDK 依赖添加

---

## 🚧 剩余工作 (15%)

### 1. WalletConnectController
**文件**: `lib/page/dapp/controller/walletconnect_controller.dart`

```dart
class WalletConnectController extends BaseController {
  final WalletConnectService _wcService = WalletConnectService.instance;
  
  @override
  void onInit() {
    super.onInit();
    _wcService.initialize();
    _listenToEvents();
  }
  
  void _listenToEvents() {
    // 监听连接请求
    _wcService.onSessionProposal.listen((event) {
      _handleConnectionRequest(event);
    });
    
    // 监听交易/签名请求
    _wcService.onSessionRequest.listen((event) {
      DAppRequestRouter().handleRequest(event);
    });
  }
  
  Future<void> _handleConnectionRequest(SessionProposalEvent event) async {
    // 显示 ConnectionRequestSheet
    // 获取当前钱包地址
    // 批准或拒绝连接
  }
}
```

### 2. DAppRequestRouter
**文件**: `lib/page/dapp/services/dapp_request_router.dart`

复用 Phase 1 & 2 的组件：
```dart
Future<String> _handleSendTransaction(SessionRequestEvent event) {
  // 1. 解析交易参数
  // 2. 显示 TransactionReviewSheet（Phase 1）
  // 3. 显示密码框
  // 4. 签名并广播
  // 5. 返回交易哈希
}

Future<String> _handlePersonalSign(SessionRequestEvent event) {
  // 1. 解析消息
  // 2. 显示 MessageSignSheet（Phase 2）
  // 3. 显示密码框
  // 4. 调用 signPersonalMessage()
  // 5. 返回签名
}
```

### 3. ConnectedDAppsPage
**文件**: `lib/page/dapp/view/connected_dapps_page.dart`

简单的列表页面：
```dart
class ConnectedDAppsPage extends BaseScaffoldPage {
  @override
  Widget getBody() {
    final sessions = WalletConnectService.instance.getActiveSessions();
    
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return ListTile(
          leading: // DApp 图标
          title: // DApp 名称
          subtitle: // 连接时间
          trailing: // 断开按钮
        );
      },
    );
  }
}
```

### 4. 路由配置
在相应文件添加注解：
```dart
@GetXRoutePage('/dapp/scan')
class DAppScannerPage extends BasePage {}

@GetXRoutePage('/dapp/connected')
class ConnectedDAppsPage extends BaseScaffoldPage {}
```

运行：
```bash
flutter pub run build_runner build
```

### 5. 更新首页扫码方法
`lib/page/home/view/home_page.dart`:
```dart
void _scanToConnectDApp() async {
  if (controller.wallet == null) {
    Toast.show('Please create a wallet first');
    return;
  }
  
  // 取消注释
  await Get.toNamed(RouteTable.dappScan);
}
```

---

## 🧪 测试流程

1. **获取 WalletConnect Project ID**
   - 访问: https://cloud.walletconnect.com/
   - 创建项目并复制 ID
   - 替换 `walletconnect_service.dart` 中的 `YOUR_PROJECT_ID_HERE`

2. **运行应用**
   ```bash
   flutter pub get
   flutter run
   ```

3. **测试扫码连接**
   - 点击首页扫码按钮
   - 扫描测试 DApp 二维码
   - 确认连接请求

4. **测试 DApp 推荐**
   - WalletConnect 测试 DApp: https://react-app.walletconnect.com/
   - Uniswap: https://app.uniswap.org/
   - OpenSea: https://opensea.io/

---

## 📊 当前状态

```
总代码量: ~2,600 行
新增文件: 12 个
完成度: 85%
预计剩余工作: 2-3 小时
```

---

## 💡 优先级

高优先级（必须）:
1. ✅ WalletConnectController
2. ✅ DAppRequestRouter
3. ✅ 路由配置

低优先级（可选）:
4. ConnectedDAppsPage（可以先用简单版本）

---

## 📚 参考文档

- 完整指南: `docs/PHASE3_IMPLEMENTATION_GUIDE.md`
- WalletConnect 文档: https://docs.walletconnect.com/
- Reown WalletKit: https://docs.reown.com/walletkit/overview
