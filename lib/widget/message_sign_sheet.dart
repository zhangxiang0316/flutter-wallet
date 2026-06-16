import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// 消息类型
enum MessageType {
  /// 普通文本消息 (EIP-191 personal_sign)
  text,

  /// 结构化数据 (EIP-712 typed data)
  typedData,

  /// 原始十六进制数据
  hex,
}

/// 消息签名确认弹窗
///
/// 在用户签名消息之前，显示：
/// - 签名请求来源（DApp 名称、URL）
/// - 消息类型和内容
/// - 签名地址
/// - 安全警告
///
/// 用户点击"Sign"后才会进入密码认证步骤。
class MessageSignSheet extends StatefulWidget {
  final String dappName;
  final String? dappUrl;
  final String? dappIcon;
  final String message;
  final MessageType messageType;
  final String signerAddress;
  final Map<String, dynamic>? typedData;
  final VoidCallback onSign;
  final VoidCallback onReject;

  const MessageSignSheet({
    Key? key,
    required this.dappName,
    this.dappUrl,
    this.dappIcon,
    required this.message,
    required this.messageType,
    required this.signerAddress,
    this.typedData,
    required this.onSign,
    required this.onReject,
  }) : super(key: key);

  @override
  State<MessageSignSheet> createState() => _MessageSignSheetState();
}

class _MessageSignSheetState extends State<MessageSignSheet> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(context),

            // DApp 信息
            _buildDAppInfo(context),

            // 消息内容
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),

                    // 安全警告
                    _buildSecurityWarning(context),

                    SizedBox(height: 20.h),

                    // 消息内容
                    _buildMessageContent(context),

                    SizedBox(height: 20.h),

                    // 签名地址
                    _buildSignerInfo(context),

                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),

            // 底部按钮
            _buildButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Sign Message',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onReject,
            icon: Icon(Icons.close, size: 24.sp),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildDAppInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: widget.dappIcon != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: Image.network(
                      widget.dappIcon!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.language,
                        size: 24.sp,
                        color: theme.primaryColor,
                      ),
                    ),
                  )
                : Icon(
                    Icons.language,
                    size: 24.sp,
                    color: theme.primaryColor,
                  ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.dappName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.dappUrl != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    widget.dappUrl!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              'Connected',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityWarning(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber.shade700,
            size: 20.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Only sign messages from trusted websites',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Signing a message does not spend gas, but it may grant permissions or prove ownership.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.amber.shade700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Message',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                _getMessageTypeLabel(),
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: _isExpanded ? double.infinity : 200.h,
          ),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getFormattedMessage(),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
                maxLines: _isExpanded ? null : 10,
                overflow: _isExpanded ? null : TextOverflow.ellipsis,
              ),
              if (_shouldShowExpandButton()) ...[
                SizedBox(height: 8.h),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Show less' : 'Show more',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16.sp,
                        color: theme.primaryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignerInfo(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Signing with',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey,
          ),
        ),
        SizedBox(height: 8.h),
        InkWell(
          onTap: () => _copyToClipboard(widget.signerAddress),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 18.sp,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    widget.signerAddress,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.copy,
                  size: 16.sp,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onReject,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Reject',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onSign,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Sign',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMessageTypeLabel() {
    switch (widget.messageType) {
      case MessageType.text:
        return 'Plain Text';
      case MessageType.typedData:
        return 'Typed Data';
      case MessageType.hex:
        return 'Raw Data';
    }
  }

  String _getFormattedMessage() {
    switch (widget.messageType) {
      case MessageType.text:
        return widget.message;
      case MessageType.typedData:
        if (widget.typedData != null) {
          // 格式化 JSON 显示
          const encoder = JsonEncoder.withIndent('  ');
          return encoder.convert(widget.typedData);
        }
        return widget.message;
      case MessageType.hex:
        // 十六进制数据，每 64 个字符换行
        final hex = widget.message.startsWith('0x')
            ? widget.message.substring(2)
            : widget.message;
        final chunks = <String>[];
        for (var i = 0; i < hex.length; i += 64) {
          chunks.add(hex.substring(
            i,
            i + 64 > hex.length ? hex.length : i + 64,
          ));
        }
        return '0x${chunks.join('\n')}';
    }
  }

  bool _shouldShowExpandButton() {
    final message = _getFormattedMessage();
    return message.split('\n').length > 10 || message.length > 500;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Copied',
      'Address copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 2),
      margin: EdgeInsets.all(16.w),
    );
  }

  /// 显示消息签名弹窗的便捷方法
  static Future<bool?> show({
    required BuildContext context,
    required String dappName,
    String? dappUrl,
    String? dappIcon,
    required String message,
    required MessageType messageType,
    required String signerAddress,
    Map<String, dynamic>? typedData,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MessageSignSheet(
          dappName: dappName,
          dappUrl: dappUrl,
          dappIcon: dappIcon,
          message: message,
          messageType: messageType,
          signerAddress: signerAddress,
          typedData: typedData,
          onSign: () => Navigator.of(context).pop(true),
          onReject: () => Navigator.of(context).pop(false),
        );
      },
    );
  }
}
