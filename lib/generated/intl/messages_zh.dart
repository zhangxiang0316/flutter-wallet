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

  static String m1(index) => "第 ${index} 个单词";

  static String m2(symbol) => "手续费将使用 ${symbol} 支付，请确认钱包中有足够余额。";

  static String m3(ms) => "备用可用 · ${ms} ms";

  static String m4(ms) => "${ms} ms";

  static String m5(symbol) => "收款 ${symbol}";

  static String m6(name) => "确定从地址簿移除「${name}」吗？";

  static String m7(symbol) => "确定要移除「${symbol}」吗？移除后首页不再查询该币种余额。";

  static String m8(name) => "确定要移除「${name}」吗？移除后不再查询该自定义网络资产。";

  static String m9(name) => "确定要移除「${name}」吗？本地保存的钱包信息会被删除。";

  static String m10(count) => "${count} 个网络";

  static String m11(symbol) => "转账 ${symbol}";

  static String m12(network) => "EVM 地址可在多个网络复用，请确认收款方希望在 ${network} 接收资产。";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "addAddressBookEntry": MessageLookupByLibrary.simpleMessage("添加联系人"),
        "addCustomAsset": MessageLookupByLibrary.simpleMessage("添加币种"),
        "addNetwork": MessageLookupByLibrary.simpleMessage("添加网络"),
        "addWallet": MessageLookupByLibrary.simpleMessage("添加钱包"),
        "addressBook": MessageLookupByLibrary.simpleMessage("地址簿"),
        "addressBookTip": MessageLookupByLibrary.simpleMessage(
            "按网络保存可信收款地址。转账时仅可选择当前网络下的联系人。"),
        "appName": MessageLookupByLibrary.simpleMessage("沐晨钱包"),
        "asset": MessageLookupByLibrary.simpleMessage("资产"),
        "assetVisibility": MessageLookupByLibrary.simpleMessage("资产显示"),
        "assetVisibilityTip": MessageLookupByLibrary.simpleMessage(
            "关闭后，该币种会从首页资产列表和估值中隐藏；链上余额不会被删除，可随时重新开启。"),
        "authenticateToUnlock":
            MessageLookupByLibrary.simpleMessage("验证身份以查看敏感信息"),
        "availableBalance": MessageLookupByLibrary.simpleMessage("可用余额"),
        "backToMnemonic": MessageLookupByLibrary.simpleMessage("返回"),
        "backToWallet": MessageLookupByLibrary.simpleMessage("返回钱包"),
        "backupMnemonic": MessageLookupByLibrary.simpleMessage("备份助记词"),
        "backupMnemonicTip": MessageLookupByLibrary.simpleMessage(
            "请按顺序抄写并离线保存这些助记词。任何人获得助记词都可以控制你的资产。"),
        "balanceLoadFailed": MessageLookupByLibrary.simpleMessage("部分余额查询失败"),
        "biometricAuthFailed":
            MessageLookupByLibrary.simpleMessage("生物识别失败，请使用密码"),
        "biometricAuthTitle": MessageLookupByLibrary.simpleMessage("生物识别验证"),
        "blockExplorer": MessageLookupByLibrary.simpleMessage("区块浏览器"),
        "blockExplorerBack": MessageLookupByLibrary.simpleMessage("后退"),
        "blockExplorerForward": MessageLookupByLibrary.simpleMessage("前进"),
        "blockExplorerOpenFailed":
            MessageLookupByLibrary.simpleMessage("无法打开区块浏览器"),
        "blockExplorerUnavailable":
            MessageLookupByLibrary.simpleMessage("当前网络暂未配置区块浏览器"),
        "blockNumber": MessageLookupByLibrary.simpleMessage("区块高度"),
        "cancel": MessageLookupByLibrary.simpleMessage("取消"),
        "chooseFromAddressBook": MessageLookupByLibrary.simpleMessage("从地址簿选择"),
        "confirmImport": MessageLookupByLibrary.simpleMessage("确认导入"),
        "confirmMnemonicBackup":
            MessageLookupByLibrary.simpleMessage("确认助记词备份"),
        "confirmMnemonicBackupTip":
            MessageLookupByLibrary.simpleMessage("请输入指定序号的单词，确认你已按正确顺序保存助记词。"),
        "confirmTransfer": MessageLookupByLibrary.simpleMessage("确认转账"),
        "confirmWalletPassword": MessageLookupByLibrary.simpleMessage("确认钱包密码"),
        "contactAddress": MessageLookupByLibrary.simpleMessage("钱包地址"),
        "contactInvalid":
            MessageLookupByLibrary.simpleMessage("请检查联系人名称、网络和地址"),
        "contactName": MessageLookupByLibrary.simpleMessage("联系人名称"),
        "contactNameHint": MessageLookupByLibrary.simpleMessage("交易所、朋友或冷钱包"),
        "contactNote": MessageLookupByLibrary.simpleMessage("备注"),
        "contactNoteHint": MessageLookupByLibrary.simpleMessage("可选标签或提醒"),
        "contactRemoved": MessageLookupByLibrary.simpleMessage("联系人已移除"),
        "contactSaved": MessageLookupByLibrary.simpleMessage("联系人已保存"),
        "contractAddress": MessageLookupByLibrary.simpleMessage("合约地址"),
        "copied": MessageLookupByLibrary.simpleMessage("已复制"),
        "copyHash": MessageLookupByLibrary.simpleMessage("复制哈希"),
        "copyLink": MessageLookupByLibrary.simpleMessage("复制链接"),
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
        "customAssetLogoUrl": MessageLookupByLibrary.simpleMessage("Logo 地址"),
        "customAssetMergeOnHome":
            MessageLookupByLibrary.simpleMessage("与首页同名代币合并"),
        "customAssetMergeOnHomeTip":
            MessageLookupByLibrary.simpleMessage("请确认合约可信后再开启；系统不会仅凭简称自动合并。"),
        "customAssetMetadataUnavailable":
            MessageLookupByLibrary.simpleMessage("暂时无法识别币种信息，请手动填写"),
        "customAssetName": MessageLookupByLibrary.simpleMessage("币种名称"),
        "customAssetSymbol": MessageLookupByLibrary.simpleMessage("币种简称"),
        "editAddressBookEntry": MessageLookupByLibrary.simpleMessage("编辑联系人"),
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
        "getStarted": MessageLookupByLibrary.simpleMessage("开始使用"),
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
        "mnemonicBackedUp": MessageLookupByLibrary.simpleMessage("助记词备份已确认"),
        "mnemonicBackedUpStatus": MessageLookupByLibrary.simpleMessage("已备份"),
        "mnemonicBackupConfirm":
            MessageLookupByLibrary.simpleMessage("我已安全备份助记词"),
        "mnemonicBackupNext": MessageLookupByLibrary.simpleMessage("我已抄写"),
        "mnemonicBackupVerifyFailed":
            MessageLookupByLibrary.simpleMessage("助记词单词不匹配，请检查备份后重试"),
        "mnemonicHint":
            MessageLookupByLibrary.simpleMessage("请输入 12 个英文助记词，使用空格分隔"),
        "mnemonicNotBackedUpStatus":
            MessageLookupByLibrary.simpleMessage("未备份"),
        "mnemonicWordNumber": m1,
        "more": MessageLookupByLibrary.simpleMessage("更多"),
        "nativeAsset": MessageLookupByLibrary.simpleMessage("原生资产"),
        "network": MessageLookupByLibrary.simpleMessage("网络"),
        "networkAdded": MessageLookupByLibrary.simpleMessage("网络已添加"),
        "networkChainId": MessageLookupByLibrary.simpleMessage("Chain ID"),
        "networkDistribution": MessageLookupByLibrary.simpleMessage("网络分布"),
        "networkDuplicate": MessageLookupByLibrary.simpleMessage("该网络已存在"),
        "networkErrorMessage":
            MessageLookupByLibrary.simpleMessage("网络连接失败，请检查网络设置"),
        "networkExplorerApiKey":
            MessageLookupByLibrary.simpleMessage("浏览器 API Key"),
        "networkExplorerApiUrl":
            MessageLookupByLibrary.simpleMessage("浏览器 API 地址"),
        "networkExplorerApiUrlHelper": MessageLookupByLibrary.simpleMessage(
            "用于查询 EVM 交易记录，可填写 Etherscan 兼容 API"),
        "networkFee": MessageLookupByLibrary.simpleMessage("网络手续费"),
        "networkFeeAsset": m2,
        "networkInvalid": MessageLookupByLibrary.simpleMessage(
            "请检查网络名称、币种简称、Chain ID 和 RPC 地址"),
        "networkManagement": MessageLookupByLibrary.simpleMessage("网络管理"),
        "networkManagementTip": MessageLookupByLibrary.simpleMessage(
            "当前仅支持添加 EVM 兼容网络。自定义网络复用钱包 EVM 地址，支持原生币和代币余额查询。"),
        "networkName": MessageLookupByLibrary.simpleMessage("网络名称"),
        "networkRemoved": MessageLookupByLibrary.simpleMessage("网络已移除"),
        "networkRpcBackupAvailable":
            MessageLookupByLibrary.simpleMessage("主 RPC 不可用，发现可用备用 RPC"),
        "networkRpcBackupHint": m3,
        "networkRpcDown": MessageLookupByLibrary.simpleMessage("不可用"),
        "networkRpcLatency": m4,
        "networkRpcMismatch":
            MessageLookupByLibrary.simpleMessage("RPC 返回的 Chain ID 不一致"),
        "networkRpcNotTested": MessageLookupByLibrary.simpleMessage("未测速"),
        "networkRpcSwitch": MessageLookupByLibrary.simpleMessage("切换"),
        "networkRpcSwitched": MessageLookupByLibrary.simpleMessage("已切换主 RPC"),
        "networkRpcTest": MessageLookupByLibrary.simpleMessage("测速"),
        "networkRpcTestAvailable":
            MessageLookupByLibrary.simpleMessage("主 RPC 可用"),
        "networkRpcTesting": MessageLookupByLibrary.simpleMessage("测速中"),
        "networkRpcUnavailable":
            MessageLookupByLibrary.simpleMessage("RPC 暂时不可用"),
        "networkRpcUrl": MessageLookupByLibrary.simpleMessage("RPC 地址"),
        "networkRpcUrlHelper":
            MessageLookupByLibrary.simpleMessage("每行一个 RPC 地址，也可以用逗号分隔"),
        "networkSymbol": MessageLookupByLibrary.simpleMessage("原生币简称"),
        "networkUpdated": MessageLookupByLibrary.simpleMessage("网络已更新"),
        "next": MessageLookupByLibrary.simpleMessage("下一步"),
        "noContacts": MessageLookupByLibrary.simpleMessage("暂无联系人"),
        "onboardingDesc1": MessageLookupByLibrary.simpleMessage(
            "支持以太坊、Solana、TRON 等多条主流公链，一个钱包管理所有资产"),
        "onboardingDesc2":
            MessageLookupByLibrary.simpleMessage("私钥加密存储在本地，截屏保护，永不上传服务器"),
        "onboardingDesc3":
            MessageLookupByLibrary.simpleMessage("支持指纹和面容识别，快速查看私钥和助记词"),
        "onboardingDesc4":
            MessageLookupByLibrary.simpleMessage("简洁的界面设计，流畅的操作体验，让数字资产管理更轻松"),
        "onboardingTitle1": MessageLookupByLibrary.simpleMessage("多链钱包"),
        "onboardingTitle2": MessageLookupByLibrary.simpleMessage("安全可靠"),
        "onboardingTitle3": MessageLookupByLibrary.simpleMessage("快速解锁"),
        "onboardingTitle4": MessageLookupByLibrary.simpleMessage("简单易用"),
        "openBlockExplorer": MessageLookupByLibrary.simpleMessage("查看区块浏览器"),
        "openInExternalBrowser":
            MessageLookupByLibrary.simpleMessage("外部浏览器打开"),
        "orUsePassword": MessageLookupByLibrary.simpleMessage("或使用密码"),
        "partialNetworkError":
            MessageLookupByLibrary.simpleMessage("部分网络余额暂时不可用，当前合计仅包含可用网络。"),
        "passwordCache": MessageLookupByLibrary.simpleMessage("密码缓存"),
        "passwordCacheClearedOnExit":
            MessageLookupByLibrary.simpleMessage("应用退出后自动清除缓存"),
        "passwordCacheDesc":
            MessageLookupByLibrary.simpleMessage("生物识别成功后自动使用缓存密码"),
        "passwordCacheDisabled":
            MessageLookupByLibrary.simpleMessage("密码缓存已禁用"),
        "passwordCacheEnabled": MessageLookupByLibrary.simpleMessage("密码缓存已启用"),
        "passwordCacheExpiresAutomatically":
            MessageLookupByLibrary.simpleMessage("超过设定时间后自动过期"),
        "passwordCacheExpiry": MessageLookupByLibrary.simpleMessage("缓存过期时间"),
        "passwordCacheExpiry1": MessageLookupByLibrary.simpleMessage("1分钟"),
        "passwordCacheExpiry10": MessageLookupByLibrary.simpleMessage("10分钟"),
        "passwordCacheExpiry30": MessageLookupByLibrary.simpleMessage("30分钟"),
        "passwordCacheExpiry5": MessageLookupByLibrary.simpleMessage("5分钟（推荐）"),
        "passwordCacheMemoryOnly":
            MessageLookupByLibrary.simpleMessage("密码仅缓存在内存中"),
        "passwordCacheSecurityNoteTitle":
            MessageLookupByLibrary.simpleMessage("安全说明"),
        "phone": MessageLookupByLibrary.simpleMessage("手机"),
        "popularTokens": MessageLookupByLibrary.simpleMessage("热门币种"),
        "primaryMultiChainWallet":
            MessageLookupByLibrary.simpleMessage("EVM / SOL / TRX 多链主钱包"),
        "privateKeyHint":
            MessageLookupByLibrary.simpleMessage("请输入 64 位十六进制私钥，可带 0x 前缀"),
        "receive": MessageLookupByLibrary.simpleMessage("收款"),
        "receiveAddress": MessageLookupByLibrary.simpleMessage("收款地址"),
        "receiveAddressEmpty":
            MessageLookupByLibrary.simpleMessage("当前钱包没有该网络地址"),
        "receiveAmount": MessageLookupByLibrary.simpleMessage("金额"),
        "receiveAmountHint": MessageLookupByLibrary.simpleMessage("选填"),
        "receiveAsset": m5,
        "receiveMemo": MessageLookupByLibrary.simpleMessage("备注"),
        "receiveMemoHint": MessageLookupByLibrary.simpleMessage("选填，最多 80 个字符"),
        "receiveQrTip":
            MessageLookupByLibrary.simpleMessage("请仅通过当前选择的网络转入该币种。"),
        "receiveQrTitle": MessageLookupByLibrary.simpleMessage("扫码收款"),
        "receiveRequestTip":
            MessageLookupByLibrary.simpleMessage("填写金额或备注后，二维码会包含收款请求信息。"),
        "receiveRequestTitle": MessageLookupByLibrary.simpleMessage("收款请求"),
        "receiveUnavailable": MessageLookupByLibrary.simpleMessage("收款信息不可用"),
        "recipientAddress": MessageLookupByLibrary.simpleMessage("收款地址"),
        "refreshBalance": MessageLookupByLibrary.simpleMessage("刷新余额"),
        "removeContact": MessageLookupByLibrary.simpleMessage("移除联系人"),
        "removeContactConfirm": m6,
        "removeCustomAsset": MessageLookupByLibrary.simpleMessage("移除币种"),
        "removeCustomAssetConfirmMessage": m7,
        "removeNetwork": MessageLookupByLibrary.simpleMessage("移除网络"),
        "removeNetworkConfirm": m8,
        "removeWallet": MessageLookupByLibrary.simpleMessage("移除钱包"),
        "removeWalletConfirmMessage": m9,
        "retry": MessageLookupByLibrary.simpleMessage("重试"),
        "reviewTransfer": MessageLookupByLibrary.simpleMessage("检查转账"),
        "saveContact": MessageLookupByLibrary.simpleMessage("保存联系人"),
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
        "screenshotNotAllowed":
            MessageLookupByLibrary.simpleMessage("为了您的安全，此页面不允许截屏"),
        "screenshotProtectionEnabled":
            MessageLookupByLibrary.simpleMessage("🔒 为保护您的资产安全，此页面已启用截屏保护"),
        "securityNotice": MessageLookupByLibrary.simpleMessage("安全提醒"),
        "securityNoticeDetail": MessageLookupByLibrary.simpleMessage(
            "私钥会使用钱包密码加密后保存到系统安全存储。请牢记密码，当前版本仍不等同于硬件钱包安全级别。"),
        "securitySettings": MessageLookupByLibrary.simpleMessage("安全设置"),
        "selectContact": MessageLookupByLibrary.simpleMessage("选择联系人"),
        "selectReceiveAsset": MessageLookupByLibrary.simpleMessage("选择收款币种"),
        "selectReceiveChain": MessageLookupByLibrary.simpleMessage("选择收款网络"),
        "selectTransferAsset": MessageLookupByLibrary.simpleMessage("转账币种"),
        "selectTransferChain": MessageLookupByLibrary.simpleMessage("转账网络"),
        "settings": MessageLookupByLibrary.simpleMessage("设置"),
        "skip": MessageLookupByLibrary.simpleMessage("跳过"),
        "splashLoading": MessageLookupByLibrary.simpleMessage("正在进入钱包"),
        "splashTagline": MessageLookupByLibrary.simpleMessage("安全管理多链资产"),
        "switchWallet": MessageLookupByLibrary.simpleMessage("切换钱包"),
        "systemErrorMessage":
            MessageLookupByLibrary.simpleMessage("操作失败，请稍后重试"),
        "theme": MessageLookupByLibrary.simpleMessage("主题"),
        "themeDark": MessageLookupByLibrary.simpleMessage("深色主题"),
        "themeLight": MessageLookupByLibrary.simpleMessage("浅色主题"),
        "themeSettings": MessageLookupByLibrary.simpleMessage("主题设置"),
        "themeSystem": MessageLookupByLibrary.simpleMessage("跟随系统"),
        "tokenAssets": MessageLookupByLibrary.simpleMessage("代币资产"),
        "tokenAssetsEmpty": MessageLookupByLibrary.simpleMessage("暂无资产"),
        "tokenContractAsset": MessageLookupByLibrary.simpleMessage("代币合约"),
        "tokenDetails": MessageLookupByLibrary.simpleMessage("代币详情"),
        "tokenNetworkCount": m10,
        "totalAssets": MessageLookupByLibrary.simpleMessage("总资产估值"),
        "totalTransferCost": MessageLookupByLibrary.simpleMessage("合计"),
        "transactionAddresses": MessageLookupByLibrary.simpleMessage("地址信息"),
        "transactionAmount": MessageLookupByLibrary.simpleMessage("数量"),
        "transactionChainInfo": MessageLookupByLibrary.simpleMessage("网络详情"),
        "transactionDetail": MessageLookupByLibrary.simpleMessage("交易详情"),
        "transactionDirection": MessageLookupByLibrary.simpleMessage("方向"),
        "transactionFrom": MessageLookupByLibrary.simpleMessage("发送方"),
        "transactionHash": MessageLookupByLibrary.simpleMessage("交易哈希"),
        "transactionHistory": MessageLookupByLibrary.simpleMessage("交易记录"),
        "transactionHistoryApiKeyInvalid": MessageLookupByLibrary.simpleMessage(
            "交易记录 API Key 无效或权限不足，请重新检查配置"),
        "transactionHistoryApiKeyMissing":
            MessageLookupByLibrary.simpleMessage("交易记录 API Key 未配置，请检查环境变量"),
        "transactionHistoryEmpty":
            MessageLookupByLibrary.simpleMessage("暂无交易记录"),
        "transactionHistoryExplorerHint":
            MessageLookupByLibrary.simpleMessage("应用内暂未查到记录，可到区块浏览器查看该地址。"),
        "transactionHistoryNoRecords":
            MessageLookupByLibrary.simpleMessage("暂无链上交易记录"),
        "transactionHistoryProviderFailed":
            MessageLookupByLibrary.simpleMessage("交易记录数据源暂不可用，请稍后重试或查看区块浏览器"),
        "transactionHistoryRateLimited":
            MessageLookupByLibrary.simpleMessage("交易记录接口请求过于频繁，请稍后再试"),
        "transactionHistoryTimeout":
            MessageLookupByLibrary.simpleMessage("交易记录接口响应超时，请稍后重试"),
        "transactionIncoming": MessageLookupByLibrary.simpleMessage("转入"),
        "transactionLoadFailed":
            MessageLookupByLibrary.simpleMessage("交易记录加载失败，请稍后重试"),
        "transactionLoadMore": MessageLookupByLibrary.simpleMessage("加载更多"),
        "transactionLoadMoreFailed":
            MessageLookupByLibrary.simpleMessage("加载更多交易记录失败"),
        "transactionNoAsset": MessageLookupByLibrary.simpleMessage("交易记录信息不可用"),
        "transactionNoMoreRecords":
            MessageLookupByLibrary.simpleMessage("没有更多交易记录"),
        "transactionOutgoing": MessageLookupByLibrary.simpleMessage("转出"),
        "transactionOverview": MessageLookupByLibrary.simpleMessage("概览"),
        "transactionRefreshStatus":
            MessageLookupByLibrary.simpleMessage("刷新状态"),
        "transactionSelfTransfer": MessageLookupByLibrary.simpleMessage("自转账"),
        "transactionSource": MessageLookupByLibrary.simpleMessage("来源"),
        "transactionSourceLocal": MessageLookupByLibrary.simpleMessage("本地"),
        "transactionSourceRemote": MessageLookupByLibrary.simpleMessage("链上"),
        "transactionStatus": MessageLookupByLibrary.simpleMessage("状态"),
        "transactionStatusFailed": MessageLookupByLibrary.simpleMessage("失败"),
        "transactionStatusPending": MessageLookupByLibrary.simpleMessage("待确认"),
        "transactionStatusRefreshFailed":
            MessageLookupByLibrary.simpleMessage("交易状态刷新失败"),
        "transactionStatusSuccess": MessageLookupByLibrary.simpleMessage("成功"),
        "transactionStatusUnknown": MessageLookupByLibrary.simpleMessage("未知"),
        "transactionSummary": MessageLookupByLibrary.simpleMessage("交易摘要"),
        "transactionTime": MessageLookupByLibrary.simpleMessage("时间"),
        "transactionTimeUnknown": MessageLookupByLibrary.simpleMessage("时间未知"),
        "transactionTo": MessageLookupByLibrary.simpleMessage("接收方"),
        "transactionUnknownDirection":
            MessageLookupByLibrary.simpleMessage("交易"),
        "transactionWalletAddress":
            MessageLookupByLibrary.simpleMessage("钱包地址"),
        "transfer": MessageLookupByLibrary.simpleMessage("转账"),
        "transferAmount": MessageLookupByLibrary.simpleMessage("转账数量"),
        "transferAsset": m11,
        "transferDetails": MessageLookupByLibrary.simpleMessage("转账信息"),
        "transferFailed":
            MessageLookupByLibrary.simpleMessage("转账失败，请检查地址、数量和链上余额"),
        "transferFromAddress": MessageLookupByLibrary.simpleMessage("发起地址"),
        "transferInputInvalid":
            MessageLookupByLibrary.simpleMessage("请输入有效的收款地址和转账数量"),
        "transferRiskBurnAddress":
            MessageLookupByLibrary.simpleMessage("收款地址是常见销毁或系统地址，转入后大概率无法找回。"),
        "transferRiskClipboardMismatch":
            MessageLookupByLibrary.simpleMessage("剪贴板中存在另一个地址，请确认收款地址没有被意外替换。"),
        "transferRiskEvmNetworkConfirm": m12,
        "transferRiskFeeUnavailable": MessageLookupByLibrary.simpleMessage(
            "暂未获取到网络手续费，请确认钱包中仍有足够原生币支付手续费。"),
        "transferRiskSelfTransfer":
            MessageLookupByLibrary.simpleMessage("收款地址与当前钱包地址相同。"),
        "transferRiskTokenContract": MessageLookupByLibrary.simpleMessage(
            "收款地址与当前代币合约地址相同，向合约地址转账可能导致资产永久丢失。"),
        "transferSubmitted": MessageLookupByLibrary.simpleMessage("交易已提交"),
        "transferUnavailable": MessageLookupByLibrary.simpleMessage("转账信息不可用"),
        "unknownErrorMessage":
            MessageLookupByLibrary.simpleMessage("未知错误，请稍后重试"),
        "unlockToView": MessageLookupByLibrary.simpleMessage("输入钱包密码后查看"),
        "unlockWallet": MessageLookupByLibrary.simpleMessage("解锁钱包"),
        "unlockWalletForTransfer":
            MessageLookupByLibrary.simpleMessage("请输入钱包密码解锁本机私钥，用于本次交易签名。"),
        "useBiometric": MessageLookupByLibrary.simpleMessage("使用生物识别"),
        "validationErrorMessage":
            MessageLookupByLibrary.simpleMessage("输入信息有误，请检查后重试"),
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
