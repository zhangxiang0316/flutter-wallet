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

  static String m2(symbol) => "转账 ${symbol}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "appName": MessageLookupByLibrary.simpleMessage("沐晨钱包"),
    "availableBalance": MessageLookupByLibrary.simpleMessage("可用余额"),
    "backToWallet": MessageLookupByLibrary.simpleMessage("返回钱包"),
    "balanceLoadFailed": MessageLookupByLibrary.simpleMessage("部分余额查询失败"),
    "confirmImport": MessageLookupByLibrary.simpleMessage("确认导入"),
    "confirmTransfer": MessageLookupByLibrary.simpleMessage("确认转账"),
    "copied": MessageLookupByLibrary.simpleMessage("已复制"),
    "copyHash": MessageLookupByLibrary.simpleMessage("复制哈希"),
    "createWallet": MessageLookupByLibrary.simpleMessage("创建钱包"),
    "email": MessageLookupByLibrary.simpleMessage("注册"),
    "estimatedNetworkFee": MessageLookupByLibrary.simpleMessage("预计网络手续费"),
    "feeEstimating": MessageLookupByLibrary.simpleMessage("正在查询手续费..."),
    "feeFallback": m0,
    "feeUnavailable": MessageLookupByLibrary.simpleMessage("暂时无法查询手续费，请稍后重试。"),
    "importPrivateKey": MessageLookupByLibrary.simpleMessage("导入私钥"),
    "importWallet": MessageLookupByLibrary.simpleMessage("导入钱包"),
    "invalidPrivateKey": MessageLookupByLibrary.simpleMessage("私钥格式不正确"),
    "loading": MessageLookupByLibrary.simpleMessage("加载中..."),
    "login": MessageLookupByLibrary.simpleMessage("登录"),
    "networkFee": MessageLookupByLibrary.simpleMessage("网络手续费"),
    "networkFeeAsset": m1,
    "phone": MessageLookupByLibrary.simpleMessage("手机"),
    "privateKeyHint": MessageLookupByLibrary.simpleMessage(
      "请输入 64 位十六进制私钥，可带 0x 前缀",
    ),
    "recipientAddress": MessageLookupByLibrary.simpleMessage("收款地址"),
    "refreshBalance": MessageLookupByLibrary.simpleMessage("刷新余额"),
    "removeWallet": MessageLookupByLibrary.simpleMessage("移除钱包"),
    "securityNotice": MessageLookupByLibrary.simpleMessage("安全提醒"),
    "securityNoticeDetail": MessageLookupByLibrary.simpleMessage(
      "当前版本使用本地存储保存私钥，仅适合测试环境。请勿导入存有真实资产的钱包。",
    ),
    "totalAssets": MessageLookupByLibrary.simpleMessage("总资产估值"),
    "transactionHash": MessageLookupByLibrary.simpleMessage("交易哈希"),
    "transfer": MessageLookupByLibrary.simpleMessage("转账"),
    "transferAmount": MessageLookupByLibrary.simpleMessage("转账数量"),
    "transferAsset": m2,
    "transferDetails": MessageLookupByLibrary.simpleMessage("转账信息"),
    "transferFailed": MessageLookupByLibrary.simpleMessage(
      "转账失败，请检查地址、数量和链上余额",
    ),
    "transferInputInvalid": MessageLookupByLibrary.simpleMessage(
      "请输入有效的收款地址和转账数量",
    ),
    "transferSubmitted": MessageLookupByLibrary.simpleMessage("交易已提交"),
    "transferUnavailable": MessageLookupByLibrary.simpleMessage("转账信息不可用"),
    "walletCreated": MessageLookupByLibrary.simpleMessage("钱包已创建"),
    "walletEmptySubtitle": MessageLookupByLibrary.simpleMessage(
      "当前初版支持 BNB Smart Chain 和 TRON 的地址管理与多资产链上余额查询。",
    ),
    "walletEmptyTitle": MessageLookupByLibrary.simpleMessage("创建或导入钱包"),
    "walletImported": MessageLookupByLibrary.simpleMessage("导入成功"),
    "walletRemoved": MessageLookupByLibrary.simpleMessage("钱包已移除"),
  };
}
