import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import 'wallet_detail_common.dart';

/// 密钥查看区域。
///
/// 私钥和助记词默认不展示，只有用户输入钱包密码解锁成功后才临时显示。
class WalletSecretSection extends StatelessWidget {
  const WalletSecretSection({
    super.key,
    required this.privateKeyText,
    required this.mnemonicText,
    required this.hasMnemonic,
    required this.isUnlockingPrivateKey,
    required this.isUnlockingMnemonic,
    required this.onUnlockPrivateKey,
    required this.onUnlockMnemonic,
  });

  /// 解锁后展示的私钥文本。
  final String privateKeyText;

  /// 解锁后展示的助记词文本。
  final String mnemonicText;

  /// 当前钱包是否保存了助记词。
  final bool hasMnemonic;

  /// 私钥解锁中的 loading 状态。
  final bool isUnlockingPrivateKey;

  /// 助记词解锁中的 loading 状态。
  final bool isUnlockingMnemonic;

  /// 点击查看私钥后的回调。
  final VoidCallback onUnlockPrivateKey;

  /// 点击查看助记词后的回调。
  final VoidCallback onUnlockMnemonic;

  @override
  Widget build(BuildContext context) {
    return WalletDetailSectionPanel(
      title: S.of(context).walletSecrets,
      children: [
        _SecretTile(
          title: S.of(context).viewPrivateKey,
          value: privateKeyText,
          loading: isUnlockingPrivateKey,
          onUnlock: onUnlockPrivateKey,
        ),
        if (hasMnemonic)
          _SecretTile(
            title: S.of(context).viewMnemonic,
            value: mnemonicText,
            loading: isUnlockingMnemonic,
            onUnlock: onUnlockMnemonic,
          ),
      ],
    );
  }
}

/// 单个敏感信息查看行。
///
/// 未解锁时显示查看按钮，解锁后显示文本和复制按钮。
class _SecretTile extends StatelessWidget {
  const _SecretTile({
    required this.title,
    required this.value,
    required this.loading,
    required this.onUnlock,
  });

  /// 行标题，例如查看私钥或查看助记词。
  final String title;

  /// 解锁后的敏感文本；为空表示仍未解锁。
  final String value;

  /// 是否正在执行解锁请求。
  final bool loading;

  /// 点击查看按钮后的解锁回调。
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final revealed = value.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    return WalletDetailPlainTile(
      leading: Container(
        width: 32.w,
        height: 32.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          Icons.lock_open_rounded,
          size: 17.w,
          color: colorScheme.error,
        ),
      ),
      title: title,
      subtitle: revealed ? value : S.of(context).unlockToView,
      subtitleMaxLines: revealed ? 4 : 1,
      trailing: revealed
          ? IconButton(
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints.tight(Size(34.w, 34.w)),
              padding: EdgeInsets.zero,
              onPressed: () => copyWalletDetailValue(context, value),
              icon: Icon(
                Icons.content_copy_rounded,
                size: 17.w,
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            )
          : IconButton(
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints.tight(Size(34.w, 34.w)),
              padding: EdgeInsets.zero,
              onPressed: loading ? null : onUnlock,
              icon: loading
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(strokeWidth: 2.w),
                    )
                  : Icon(
                      Icons.visibility_rounded,
                      size: 18.w,
                      color: colorScheme.primary,
                    ),
            ),
    );
  }
}
