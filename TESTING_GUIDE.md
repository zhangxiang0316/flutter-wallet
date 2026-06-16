# DApp 扫码授权功能 - 测试指南

## 🚀 快速开始

### 1. 获取 WalletConnect Project ID（必须）

WalletConnect 需要一个 Project ID 才能工作。

**步骤：**
1. 访问: https://cloud.walletconnect.com/
2. 注册/登录账号
3. 点击 "Create" 创建新项目
4. 项目名称: `Omnicast Wallet`
5. 复制生成的 **Project ID**
6. 打开 `lib/wallet/services/walletconnect_service.dart`
7. 找到第 285 行左右:
   ```dart
   const projectId = 'YOUR_PROJECT_ID_HERE';
   ```
8. 替换为你的 Project ID:
   ```dart
   const projectId = 'abc123def456...';  // 你的真实 ID
   ```

### 2. 运行应用

```bash
flutter run
```

或在 IDE 中点击运行按钮。

---

## 🧪 功能测试清单

### Phase 1: 转账安全测试

- [ ] 进入转账页面
- [ ] 输入收款地址和金额
- [ ] 点击 "Review Transfer" 按钮
- [ ] 查看交易详情页面
  - [ ] 显示 From/To/Amount/Fee
  - [ ] 显示网络名称
- [ ] 测试大额转账（>50% 余额）
  - [ ] 应该显示橙色/红色警告
- [ ] 点击 "Approve & Sign"
- [ ] 查看密码框中的交易摘要
- [ ] 输入密码完成转账

### Phase 2: 消息签名测试

（DApp 连接后自动测试，见下方）

### Phase 3: WalletConnect 测试

#### 3.1 扫码连接

- [ ] 打开应用首页
- [ ] 点击右上角扫码图标 🔍
- [ ] 应该打开相机扫描界面
- [ ] 扫描 WalletConnect 二维码
  - 推荐使用: https://react-app.walletconnect.com/
  - 在电脑上打开，点击 "Connect Wallet"
  - 选择 "WalletConnect"
  - 会显示二维码
- [ ] 扫描成功后自动返回
- [ ] 应该弹出连接请求确认界面

#### 3.2 连接请求确认

- [ ] 查看 DApp 信息
  - [ ] DApp 图标
  - [ ] DApp 名称
  - [ ] DApp URL
- [ ] 查看权限说明
  - [ ] "View your wallet balance and activity"
  - [ ] "Request approval for transactions"
  - [ ] "Request message signatures"
- [ ] 查看请求的网络
  - [ ] 应该显示 "Ethereum" 等网络标签
- [ ] 查看连接的钱包地址
- [ ] 点击 "Connect" 批准连接
- [ ] 应该显示 "Session approved" 提示

#### 3.3 交易请求测试

**在测试 DApp 上：**
- [ ] 点击 "Send Transaction"
- [ ] 填写交易参数

**在钱包中：**
- [ ] 应该自动弹出交易审查界面（Phase 1）
- [ ] 显示 DApp 名称
- [ ] 显示交易详情
- [ ] 点击 "Approve & Sign"
- [ ] 输入密码
- [ ] 交易签名完成
- [ ] DApp 收到交易哈希

#### 3.4 签名请求测试

**在测试 DApp 上：**
- [ ] 点击 "Sign Message" 或 "Sign Typed Data"

**在钱包中：**
- [ ] 应该弹出消息签名界面（Phase 2）
- [ ] 显示 DApp 信息
- [ ] 显示消息内容（可展开/折叠）
- [ ] 显示消息类型标识
- [ ] 点击 "Sign"
- [ ] 输入密码
- [ ] 签名完成
- [ ] DApp 收到签名结果

#### 3.5 DApp 管理测试

- [ ] 返回首页
- [ ] 进入设置或添加导航到 DApp 管理页面
  - **临时方法**：在代码中添加按钮跳转到 `/dapp/connected`
- [ ] 查看已连接的 DApp 列表
  - [ ] 显示 DApp 图标
  - [ ] 显示 DApp 名称和 URL
- [ ] 点击某个 DApp
  - [ ] 查看详情
- [ ] 点击断开连接按钮
- [ ] 确认断开
- [ ] DApp 应该显示连接已断开

---

## 🌐 推荐测试 DApp

### 1. WalletConnect 官方测试 DApp（推荐）
- **URL**: https://react-app.walletconnect.com/
- **功能**: 支持所有 WalletConnect 功能
- **测试项**:
  - ✅ 连接/断开
  - ✅ 发送交易
  - ✅ Personal Sign
  - ✅ Sign Typed Data
  - ✅ 切换网络

### 2. Uniswap
- **URL**: https://app.uniswap.org/
- **功能**: DeFi 交易
- **测试项**:
  - ✅ 连接钱包
  - ✅ 代币授权
  - ✅ 交易签名

### 3. OpenSea
- **URL**: https://opensea.io/
- **功能**: NFT 市场
- **测试项**:
  - ✅ 连接钱包
  - ✅ NFT 签名
  - ✅ 出价/购买

---

## 🐛 常见问题

### 1. "WalletConnect not initialized"
- **原因**: 没有设置 Project ID
- **解决**: 按照第 1 步获取并设置 Project ID

### 2. "Pairing failed"
- **原因**: 二维码无效或网络问题
- **解决**: 
  - 重新生成二维码
  - 检查网络连接
  - 确保二维码是 WalletConnect v2 格式

### 3. "No wallet available"
- **原因**: 没有创建钱包
- **解决**: 先创建或导入一个钱包

### 4. 扫码页面卡住
- **原因**: 相机权限未授予
- **解决**: 在系统设置中授予相机权限

### 5. 交易发送失败
- **原因**: 
  - 余额不足
  - Gas 费用太低
  - 网络拥堵
- **解决**: 检查余额和网络状态

---

## 📊 性能指标

正常情况下的响应时间：

| 操作 | 预期时间 |
|------|----------|
| 扫码识别 | < 1 秒 |
| 连接请求显示 | < 0.5 秒 |
| 交易审查显示 | < 0.5 秒 |
| 签名完成 | 1-2 秒 |
| 会话断开 | < 1 秒 |

---

## 🎯 测试完成标准

所有以下功能正常工作即为测试通过：

- ✅ 扫码连接成功
- ✅ 显示连接确认界面
- ✅ 批准连接成功
- ✅ 接收交易请求并显示审查界面
- ✅ 交易签名成功
- ✅ 接收消息签名请求并显示签名界面
- ✅ 消息签名成功
- ✅ 查看已连接 DApp 列表
- ✅ 断开连接成功

---

## 📝 反馈

如果遇到问题，请记录：
1. 操作步骤
2. 错误信息
3. 设备和系统版本
4. 测试的 DApp URL

祝测试顺利！🎉
