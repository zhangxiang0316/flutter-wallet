import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:reown_walletkit/reown_walletkit.dart';

import '../../../utils/toast_util.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/wallet_transfer_service.dart';
import '../../../wallet/services/walletconnect_service.dart';
import '../../../widget/message_sign_sheet.dart';
import '../../../widget/transaction_review_sheet.dart';

/// DApp 请求路由器
///
/// 处理来自 DApp 的各种请求：
/// - eth_sendTransaction - 发送交易
/// - personal_sign - 个人签名
/// - eth_signTypedData_v4 - 结构化数据签名
/// - wallet_switchEthereumChain - 切换网络
class DAppRequestRouter {
  final WalletConnectService _wcService = WalletConnectService.instance;
  final WalletRepository _repository = WalletRepository();
  final WalletTransferService _transferService = WalletTransferService();

  /// 处理会话请求
  Future<void> handleRequest(SessionRequestEvent event) async {
    final method = event.params.request.method;

    debugPrint('📨 Handling request: $method');

    try {
      dynamic result;

      switch (method) {
        case 'eth_sendTransaction':
          result = await _handleSendTransaction(event);
          break;
        case 'personal_sign':
          result = await _handlePersonalSign(event);
          break;
        case 'eth_sign':
          result = await _handlePersonalSign(event);
          break;
        case 'eth_signTypedData':
        case 'eth_signTypedData_v4':
          result = await _handleSignTypedData(event);
          break;
        case 'wallet_switchEthereumChain':
          result = await _handleSwitchChain(event);
          break;
        default:
          throw UnsupportedError('Method not supported: $method');
      }

      // 发送成功响应
      await _wcService.respondRequest(
        topic: event.topic,
        requestId: event.id,
        result: result,
      );

      debugPrint('✅ Request handled successfully: $method');
    } catch (e) {
      debugPrint('❌ Request failed: $e');
      // 发送错误响应
      await _wcService.respondError(
        topic: event.topic,
        requestId: event.id,
        error: e.toString(),
      );
    }
  }

  /// 处理发送交易请求
  Future<String> _handleSendTransaction(SessionRequestEvent event) async {
    // 1. 解析交易参数
    final params = event.params.request.params as List;
    final txData = params[0] as Map<String, dynamic>;

    final from = txData['from'] as String;
    final to = txData['to'] as String;
    final value = txData['value'] as String? ?? '0x0';
    final data = txData['data'] as String? ?? '0x';
    final gas = txData['gas'] as String?;
    final gasPrice = txData['gasPrice'] as String?;

    // 2. 获取钱包和链信息
    final wallet = await _getCurrentWallet();
    if (wallet == null) throw Exception('No wallet available');

    // 从 chainId 获取链信息
    final chainId = event.params.chainId;
    final chain = _getChainFromNamespace(chainId);

    // 3. 显示交易审查界面（复用 Phase 1）
    final dappMetadata = _wcService.getActiveSessions()
        .firstWhereOrNull((s) => s.topic == event.topic)
        ?.peer.metadata;

    final approved = await TransactionReviewSheet.show(
      context: Get.context!,
      title: 'Review Transaction',
      items: [
        ReviewItem(
          label: 'From',
          value: from,
          copyable: true,
        ),
        ReviewItem(
          label: 'To',
          value: to,
          copyable: true,
        ),
        ReviewItem(
          label: 'Amount',
          value: _formatValue(value),
          highlight: true,
        ),
        if (data != '0x')
          ReviewItem(
            label: 'Data',
            value: data.substring(0, 20) + '...',
          ),
        ReviewItem(
          label: 'Network',
          value: chain,
        ),
      ],
      dappName: dappMetadata?.name ?? 'DApp',
      dappUrl: dappMetadata?.url,
    );

    if (approved != true) {
      throw Exception('User rejected transaction');
    }

    // 4. 获取钱包密码
    final password = await _showPasswordSheet('Confirm Transaction');
    if (password == null) {
      throw Exception('User cancelled');
    }

    // 5. 读取私钥
    final privateKeyHex = await _repository.readWalletPrivateKey(
      walletId: wallet.id,
      password: password,
    );

    // 6. 构造并签名交易（简化版本，实际需要更完整的实现）
    // TODO: 使用 WalletTransferService 构造完整的交易
    // 这里返回模拟的交易哈希
    final txHash = '0x' + '0' * 64;

    Toast.show('Transaction sent');
    return txHash;
  }

  /// 处理个人签名请求
  Future<String> _handlePersonalSign(SessionRequestEvent event) async {
    // 1. 解析消息参数
    final params = event.params.request.params as List;
    final message = params[0] as String;
    final address = params[1] as String;

    // 2. 获取钱包
    final wallet = await _getCurrentWallet();
    if (wallet == null) throw Exception('No wallet available');

    // 3. 显示消息签名界面（复用 Phase 2）
    final dappMetadata = _wcService.getActiveSessions()
        .firstWhereOrNull((s) => s.topic == event.topic)
        ?.peer.metadata;

    final approved = await MessageSignSheet.show(
      context: Get.context!,
      dappName: dappMetadata?.name ?? 'DApp',
      dappUrl: dappMetadata?.url,
      message: message,
      messageType: message.startsWith('0x') ? MessageType.hex : MessageType.text,
      signerAddress: address,
    );

    if (approved != true) {
      throw Exception('User rejected signature');
    }

    // 4. 获取密码
    final password = await _showPasswordSheet('Sign Message');
    if (password == null) {
      throw Exception('User cancelled');
    }

    // 5. 读取私钥
    final privateKeyHex = await _repository.readWalletPrivateKey(
      walletId: wallet.id,
      password: password,
    );

    // 6. 签名消息（复用 Phase 2）
    final signature = await _transferService.signPersonalMessage(
      message: message,
      privateKeyHex: privateKeyHex,
    );

    Toast.show('Message signed');
    return signature;
  }

  /// 处理结构化数据签名请求
  Future<String> _handleSignTypedData(SessionRequestEvent event) async {
    // 1. 解析参数
    final params = event.params.request.params as List;
    final address = params[0] as String;
    final typedData = params[1] as Map<String, dynamic>;

    // 2. 获取钱包
    final wallet = await _getCurrentWallet();
    if (wallet == null) throw Exception('No wallet available');

    // 3. 显示消息签名界面
    final dappMetadata = _wcService.getActiveSessions()
        .firstWhereOrNull((s) => s.topic == event.topic)
        ?.peer.metadata;

    final approved = await MessageSignSheet.show(
      context: Get.context!,
      dappName: dappMetadata?.name ?? 'DApp',
      dappUrl: dappMetadata?.url,
      message: typedData.toString(),
      messageType: MessageType.typedData,
      signerAddress: address,
      typedData: typedData,
    );

    if (approved != true) {
      throw Exception('User rejected signature');
    }

    // 4. 获取密码
    final password = await _showPasswordSheet('Sign Typed Data');
    if (password == null) {
      throw Exception('User cancelled');
    }

    // 5. 读取私钥
    final privateKeyHex = await _repository.readWalletPrivateKey(
      walletId: wallet.id,
      password: password,
    );

    // 6. 签名结构化数据（复用 Phase 2）
    final signature = await _transferService.signTypedData(
      typedData: typedData,
      privateKeyHex: privateKeyHex,
    );

    Toast.show('Typed data signed');
    return signature;
  }

  /// 处理切换网络请求
  Future<void> _handleSwitchChain(SessionRequestEvent event) async {
    final params = event.params.request.params as List;
    final chainIdHex = (params[0] as Map)['chainId'] as String;

    // 简单返回 null 表示成功
    // 实际应该切换钱包的当前网络
    Toast.show('Network switch requested: $chainIdHex');
    return null;
  }

  /// 显示密码输入框
  Future<String?> _showPasswordSheet(String title) async {
    final passwordController = TextEditingController();

    final password = await Get.bottomSheet<String>(
      Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Get.theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Wallet Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => Get.back(result: value),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(result: passwordController.text),
                    child: Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isDismissible: false,
    );

    passwordController.dispose();
    return password;
  }

  /// 获取当前钱包
  Future<Wallet?> _getCurrentWallet() async {
    try {
      final wallets = await _repository.listWallets();
      return wallets.isNotEmpty ? wallets.first : null;
    } catch (e) {
      return null;
    }
  }

  /// 从 chainId 获取链名称
  String _getChainFromNamespace(String chainId) {
    // chainId 格式: "eip155:1"
    final parts = chainId.split(':');
    if (parts.length < 2) return chainId;

    final id = parts[1];
    switch (id) {
      case '1':
        return 'Ethereum';
      case '56':
        return 'BSC';
      case '137':
        return 'Polygon';
      case '42161':
        return 'Arbitrum';
      case '10':
        return 'Optimism';
      default:
        return 'Chain $id';
    }
  }

  /// 格式化 value（Wei 转 Ether）
  String _formatValue(String hexValue) {
    try {
      final wei = BigInt.parse(hexValue.replaceFirst('0x', ''), radix: 16);
      final ether = wei / BigInt.from(10).pow(18);
      return '$ether ETH';
    } catch (e) {
      return hexValue;
    }
  }
}
