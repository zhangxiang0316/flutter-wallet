// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'zh';

  static String m0(amount) => "最高约 ${amount}";

  static String m1(symbol) => "手续费将使用 ${symbol} 支付，请确认钱包中有足够余额。";

  static String m2(symbol) => "收款 ${symbol}";

  static String m3(symbol) => "确定要移除「${symbol}」吗？移除后首页不再查询该币种余额。";

  static String m4(name) => "确定要移除「${name}」吗？移除后不再查询该自定义网络资产。";

  static String m5(name) => "确定要移除「${name}」吗？本地保存的钱包信息会被删除。";

  static String m6(symbol) => "转账 ${symbol}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "addCustomAsset": MessageLookupByLibrary.simpleMessage("添加币种"),
        "addNetwork": MessageLookupByLibrary.simpleMessage("添加网络"),
        "addWallet": MessageLookupByLibrary.simpleMessage("添加钱包"),
        "appName": MessageLookupByLibrary.simpleMessage("沐晨钱包"),
        "assetVisibility": MessageLookupByLibrary.simpleMessage("资产显示"),
        "assetVisibilityTip": MessageLookupByLibrary.simpleMessage(
            "关闭后，该币种会从首页资产列表和估值中隐藏；链上余额不会被删除，可随时重新开启。"),
        "availableBalance": MessageLookupByLibrary.simpleMessage("可用余额"),
        "backToWallet": MessageLookupByLibrary.simpleMessage("返回钱包"),
        "backupMnemonic": MessageLookupByLibrary.simpleMessage("备份助记词"),
        "backupMnemonicTip": MessageLookupByLibrary.simpleMessage(
            "请按顺序抄写并离线保存这些助记词。任何人获得助记词都可以控制你的资产。"),
        "balanceLoadFailed": MessageLookupByLibrary.simpleMessage("部分余额查询失败"),
        "cancel": MessageLookupByLibrary.simpleMessage("取消"),
        "confirmImport": MessageLookupByLibrary.simpleMessage("确认导入"),
        "confirmTransfer": MessageLookupByLibrary.simpleMessage("确认转账"),
        "confirmWalletPassword": MessageLookupByLibrary.simpleMessage("确认钱包密码"),
        "copied": MessageLookupByLibrary.simpleMessage("已复制"),
        "copyHash": MessageLookupByLibrary.simpleMessage("复制哈希"),
        "copyReceiveAddress": MessageLookupByLibrary.simpleMessage("复制地址"),
        "copyWalletAddress": MessageLookupByLibrary.simpleMessage("复制钱包地址"),
        "createWallet": MessageLookupByLibrary.simpleMessage("创建钱包"),
        "customAssetAdded": MessageLookupByLibrary.simpleMessage("币种已添加"),
        "customAssetContractAddress":
            MessageLookupByLibrary.simpleMessage("合约地址"),
        "customAssetContractHint":
            MessageLookupByLibrary.simpleMessage("请输入当前链上的代币合约或 Mint 地址"),
        "customAssetDecimals": MessageLookupByLibrary.simpleMessage("精度"),
        "customAssetDuplicate": MessageLookupByLibrary.simpleMessage("该币种已存在"),
        "customAssetInvalid":
            MessageLookupByLibrary.simpleMessage("请检查合约地址、简称、名称和精度"),
        "customAssetMetadataUnavailable":
            MessageLookupByLibrary.simpleMessage("暂时无法识别币种信息，请手动填写"),
        "customAssetName": MessageLookupByLibrary.simpleMessage("币种名称"),
        "customAssetSymbol": MessageLookupByLibrary.simpleMessage("币种简称"),
        "editNetwork": MessageLookupByLibrary.simpleMessage("编辑网络"),
        "editWalletName": MessageLookupByLibrary.simpleMessage("修改钱包名称"),
        "email": MessageLookupByLibrary.simpleMessage("注册"),
        "encryptWallet": MessageLookupByLibrary.simpleMessage("加密钱包"),
        "estimatedNetworkFee": MessageLookupByLibrary.simpleMessage("预计网络手续费"),
        "feeEstimating": MessageLookupByLibrary.simpleMessage("正在查询手续费..."),
        "feeFallback": m0,
        "feeUnavailable":
            MessageLookupByLibrary.simpleMessage("暂时无法查询手续费，请稍后重试。"),
        "fetchTokenInfo": MessageLookupByLibrary.simpleMessage("自动识别币种信息"),
        "importMnemonic": MessageLookupByLibrary.simpleMessage("导入助记词"),
        "importPrivateKey": MessageLookupByLibrary.simpleMessage("导入私钥"),
        "importWallet": MessageLookupByLibrary.simpleMessage("导入钱包"),
        "invalidMnemonic": MessageLookupByLibrary.simpleMessage("助记词格式不正确"),
        "invalidPrivateKey": MessageLookupByLibrary.simpleMessage("私钥格式不正确"),
        "invalidWalletPassword":
            MessageLookupByLibrary.simpleMessage("钱包密码不正确"),
        "language": MessageLookupByLibrary.simpleMessage("语言"),
        "loading": MessageLookupByLibrary.simpleMessage("加载中..."),
        "login": MessageLookupByLibrary.simpleMessage("登录"),
        "mnemonic": MessageLookupByLibrary.simpleMessage("助记词"),
        "mnemonicBackupConfirm":
            MessageLookupByLibrary.simpleMessage("我已安全备份助记词"),
        "mnemonicHint":
            MessageLookupByLibrary.simpleMessage("请输入 12 个英文助记词，使用空格分隔"),
        "networkAdded": MessageLookupByLibrary.simpleMessage("网络已添加"),
        "networkChainId": MessageLookupByLibrary.simpleMessage("Chain ID"),
        "networkDuplicate": MessageLookupByLibrary.simpleMessage("该网络已存在"),
        "networkExplorerApiKey":
            MessageLookupByLibrary.simpleMessage("浏览器 API Key"),
        "networkExplorerApiUrl":
            MessageLookupByLibrary.simpleMessage("浏览器 API 地址"),
        "networkExplorerApiUrlHelper": MessageLookupByLibrary.simpleMessage(
            "用于查询 EVM 交易记录，可填写 Etherscan 兼容 API"),
        "networkFee": MessageLookupByLibrary.simpleMessage("网络手续费"),
        "networkFeeAsset": m1,
        "networkInvalid": MessageLookupByLibrary.simpleMessage(
            "请检查网络名称、币种简称、Chain ID 和 RPC 地址"),
        "networkManagement": MessageLookupByLibrary.simpleMessage("网络管理"),
        "networkManagementTip": MessageLookupByLibrary.simpleMessage(
            "当前仅支持添加 EVM 兼容网络。自定义网络复用钱包 EVM 地址，支持原生币和代币余额查询。"),
        "networkName": MessageLookupByLibrary.simpleMessage("网络名称"),
        "networkRemoved": MessageLookupByLibrary.simpleMessage("网络已移除"),
        "networkRpcMismatch":
            MessageLookupByLibrary.simpleMessage("RPC 返回的 Chain ID 不一致"),
        "networkRpcUnavailable":
            MessageLookupByLibrary.simpleMessage("RPC 暂时不可用"),
        "networkRpcUrl": MessageLookupByLibrary.simpleMessage("RPC 地址"),
        "networkRpcUrlHelper":
            MessageLookupByLibrary.simpleMessage("每行一个 RPC 地址，也可以用逗号分隔"),
        "networkSymbol": MessageLookupByLibrary.simpleMessage("原生币简称"),
        "networkUpdated": MessageLookupByLibrary.simpleMessage("网络已更新"),
        "phone": MessageLookupByLibrary.simpleMessage("手机"),
        "primaryMultiChainWallet":
            MessageLookupByLibrary.simpleMessage("EVM / SOL / TRX 多链主钱包"),
        "privateKeyHint":
            MessageLookupByLibrary.simpleMessage("请输入 64 位十六进制私钥，可带 0x 前缀"),
        "receive": MessageLookupByLibrary.simpleMessage("收款"),
        "receiveAddress": MessageLookupByLibrary.simpleMessage("收款地址"),
        "receiveAddressEmpty":
            MessageLookupByLibrary.simpleMessage("当前钱包没有该网络地址"),
        "receiveAsset": m2,
        "receiveQrTip":
            MessageLookupByLibrary.simpleMessage("请仅通过当前选择的网络转入该币种。"),
        "receiveQrTitle": MessageLookupByLibrary.simpleMessage("扫码收款"),
        "receiveUnavailable": MessageLookupByLibrary.simpleMessage("收款信息不可用"),
        "recipientAddress": MessageLookupByLibrary.simpleMessage("收款地址"),
        "refreshBalance": MessageLookupByLibrary.simpleMessage("刷新余额"),
        "removeCustomAsset": MessageLookupByLibrary.simpleMessage("移除币种"),
        "removeCustomAssetConfirmMessage": m3,
        "removeNetwork": MessageLookupByLibrary.simpleMessage("移除网络"),
        "removeNetworkConfirm": m4,
        "removeWallet": MessageLookupByLibrary.simpleMessage("移除钱包"),
        "removeWalletConfirmMessage": m5,
        "saveNetwork": MessageLookupByLibrary.simpleMessage("保存网络"),
        "saveWalletName": MessageLookupByLibrary.simpleMessage("保存名称"),
        "scanCameraError":
            MessageLookupByLibrary.simpleMessage("相机不可用，请检查相机权限后重试。"),
        "scanNoAddressFound":
            MessageLookupByLibrary.simpleMessage("未在二维码中识别到钱包地址"),
        "scanRecipientAddress": MessageLookupByLibrary.simpleMessage("扫码地址"),
        "scanRecipientAddressTip":
            MessageLookupByLibrary.simpleMessage("将二维码对准取景框，识别后会自动填写收款地址。"),
        "scanSwitchCamera": MessageLookupByLibrary.simpleMessage("切换摄像头"),
        "scanToggleFlash": MessageLookupByLibrary.simpleMessage("切换闪光灯"),
        "securityNotice": MessageLookupByLibrary.simpleMessage("安全提醒"),
        "securityNoticeDetail": MessageLookupByLibrary.simpleMessage(
            "私钥会使用钱包密码加密后保存到系统安全存储。请牢记密码，当前版本仍不等同于硬件钱包安全级别。"),
        "selectReceiveAsset": MessageLookupByLibrary.simpleMessage("选择收款币种"),
        "selectReceiveChain": MessageLookupByLibrary.simpleMessage("选择收款网络"),
        "selectTransferAsset": MessageLookupByLibrary.simpleMessage("转账币种"),
        "selectTransferChain": MessageLookupByLibrary.simpleMessage("转账网络"),
        "settings": MessageLookupByLibrary.simpleMessage("设置"),
        "switchWallet": MessageLookupByLibrary.simpleMessage("切换钱包"),
        "theme": MessageLookupByLibrary.simpleMessage("主题"),
        "themeDark": MessageLookupByLibrary.simpleMessage("深色主题"),
        "themeLight": MessageLookupByLibrary.simpleMessage("浅色主题"),
        "themeSystem": MessageLookupByLibrary.simpleMessage("跟随系统"),
        "totalAssets": MessageLookupByLibrary.simpleMessage("总资产估值"),
        "transactionFrom": MessageLookupByLibrary.simpleMessage("发送方"),
        "transactionHash": MessageLookupByLibrary.simpleMessage("交易哈希"),
        "transactionHistory": MessageLookupByLibrary.simpleMessage("交易记录"),
        "transactionHistoryEmpty":
            MessageLookupByLibrary.simpleMessage("暂无交易记录"),
        "transactionIncoming": MessageLookupByLibrary.simpleMessage("转入"),
        "transactionLoadFailed":
            MessageLookupByLibrary.simpleMessage("交易记录加载失败，请稍后重试"),
        "transactionNoAsset": MessageLookupByLibrary.simpleMessage("交易记录信息不可用"),
        "transactionOutgoing": MessageLookupByLibrary.simpleMessage("转出"),
        "transactionSelfTransfer": MessageLookupByLibrary.simpleMessage("自转账"),
        "transactionSourceLocal": MessageLookupByLibrary.simpleMessage("本地"),
        "transactionSourceRemote": MessageLookupByLibrary.simpleMessage("链上"),
        "transactionStatusFailed": MessageLookupByLibrary.simpleMessage("失败"),
        "transactionStatusPending": MessageLookupByLibrary.simpleMessage("待确认"),
        "transactionStatusSuccess": MessageLookupByLibrary.simpleMessage("成功"),
        "transactionStatusUnknown": MessageLookupByLibrary.simpleMessage("未知"),
        "transactionTimeUnknown": MessageLookupByLibrary.simpleMessage("时间未知"),
        "transactionTo": MessageLookupByLibrary.simpleMessage("接收方"),
        "transactionUnknownDirection":
            MessageLookupByLibrary.simpleMessage("交易"),
        "transfer": MessageLookupByLibrary.simpleMessage("转账"),
        "transferAmount": MessageLookupByLibrary.simpleMessage("转账数量"),
        "transferAsset": m6,
        "transferDetails": MessageLookupByLibrary.simpleMessage("转账信息"),
        "transferFailed":
            MessageLookupByLibrary.simpleMessage("转账失败，请检查地址、数量和链上余额"),
        "transferFromAddress": MessageLookupByLibrary.simpleMessage("发起地址"),
        "transferInputInvalid":
            MessageLookupByLibrary.simpleMessage("请输入有效的收款地址和转账数量"),
        "transferSubmitted": MessageLookupByLibrary.simpleMessage("交易已提交"),
        "transferUnavailable": MessageLookupByLibrary.simpleMessage("转账信息不可用"),
        "unlockToView": MessageLookupByLibrary.simpleMessage("输入钱包密码后查看"),
        "unlockWallet": MessageLookupByLibrary.simpleMessage("解锁钱包"),
        "unlockWalletForTransfer":
            MessageLookupByLibrary.simpleMessage("请输入钱包密码解锁本机私钥，用于本次交易签名。"),
        "viewMnemonic": MessageLookupByLibrary.simpleMessage("查看助记词"),
        "viewPrivateKey": MessageLookupByLibrary.simpleMessage("查看私钥"),
        "walletAddresses": MessageLookupByLibrary.simpleMessage("链地址"),
        "walletCreated": MessageLookupByLibrary.simpleMessage("钱包已创建"),
        "walletDetails": MessageLookupByLibrary.simpleMessage("钱包详情"),
        "walletEmptySubtitle": MessageLookupByLibrary.simpleMessage(
            "当前支持 BNB Smart Chain、Ethereum、X Layer、Solana 和 TRON 的地址管理与多资产链上余额查询。"),
        "walletEmptyTitle": MessageLookupByLibrary.simpleMessage("创建或导入钱包"),
        "walletImported": MessageLookupByLibrary.simpleMessage("导入成功"),
        "walletName": MessageLookupByLibrary.simpleMessage("钱包名称"),
        "walletNameRequired": MessageLookupByLibrary.simpleMessage("请输入钱包名称"),
        "walletNameUpdated": MessageLookupByLibrary.simpleMessage("钱包名称已更新"),
        "walletPassword": MessageLookupByLibrary.simpleMessage("钱包密码"),
        "walletPasswordHint":
            MessageLookupByLibrary.simpleMessage("至少 6 位，用于加密本机私钥和转账前解锁。"),
        "walletPasswordMismatch":
            MessageLookupByLibrary.simpleMessage("两次输入的钱包密码不一致"),
        "walletPasswordRequired":
            MessageLookupByLibrary.simpleMessage("请输入钱包密码"),
        "walletPasswordTooShort":
            MessageLookupByLibrary.simpleMessage("钱包密码至少 6 位"),
        "walletRemoved": MessageLookupByLibrary.simpleMessage("钱包已移除"),
        "walletSecretMissing":
            MessageLookupByLibrary.simpleMessage("未找到该钱包的加密私钥"),
        "walletSecrets": MessageLookupByLibrary.simpleMessage("钱包密钥"),
        "walletSecurityMigrated":
            MessageLookupByLibrary.simpleMessage("钱包私钥已加密保存"),
        "walletSecurityMigrationFailed":
            MessageLookupByLibrary.simpleMessage("钱包私钥加密失败，请重试"),
        "walletSecurityUpgrade": MessageLookupByLibrary.simpleMessage("升级钱包安全"),
        "walletSolanaAddressUpgrade":
            MessageLookupByLibrary.simpleMessage("补全 Solana 地址"),
        "walletSolanaAddressUpgradeAction":
            MessageLookupByLibrary.simpleMessage("补全地址"),
        "walletSolanaAddressUpgradeDetail":
            MessageLookupByLibrary.simpleMessage(
                "当前钱包创建于支持 Solana 之前，需要输入钱包密码解锁本机私钥并派生 Solana 地址。"),
        "walletSolanaAddressUpgradeFailed":
            MessageLookupByLibrary.simpleMessage("Solana 地址补全失败，请重试"),
        "walletSolanaAddressUpgraded":
            MessageLookupByLibrary.simpleMessage("Solana 地址已补全")
      };
}
