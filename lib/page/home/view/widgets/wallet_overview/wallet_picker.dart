part of '../wallet_overview_card.dart';

class _WalletPickerHeader extends StatelessWidget {
  const _WalletPickerHeader({required this.onAddWallet});

  /// 点击右侧加号后的添加钱包入口。
  final VoidCallback onAddWallet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            S.of(context).switchWallet,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: S.of(context).addWallet,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints.tight(Size(34.w, 34.w)),
            padding: EdgeInsets.zero,
            onPressed: onAddWallet,
            icon: Container(
              width: 28.w,
              height: 28.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: colorScheme.primary,
                size: 20.w,
              ),
            ),
            tooltip: S.of(context).addWallet,
          ),
        ),
        SizedBox(width: 8.w),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: BoxConstraints.tight(Size(32.w, 32.w)),
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.close_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
            size: 20.w,
          ),
        ),
      ],
    );
  }
}

/// 钱包切换弹窗顶部的当前钱包预览。
class _CurrentWalletPreview extends StatelessWidget {
  const _CurrentWalletPreview({required this.wallet});

  /// 当前首页正在使用的钱包。
  final WalletAccount wallet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _WalletAvatar(wallet: wallet, selected: true, size: 40),
          SizedBox(width: 11.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6.h),
                _WalletAddressLine(
                  bscAddress: wallet.bscAddress,
                  solanaAddress: wallet.solanaAddress,
                  tronAddress: wallet.tronAddress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 打开钱包切换底部弹窗。
///
/// 弹窗内部只负责选择、添加和移除确认的 UI 编排，实际钱包状态更新由传入回调完成。
void _showWalletPicker({
  required BuildContext context,
  required WalletAccount wallet,
  required List<WalletAccount> wallets,
  required ValueChanged<WalletAccount> onWalletSelected,
  required Future<void> Function(WalletAccount wallet) onWalletRemoved,
  required VoidCallback onAddWallet,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      // 使用弹窗自身 context 的主题，避免跨 route 后主题引用不一致。
      final colorScheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        top: false,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(top: 9.h, bottom: 14.h),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                child: _WalletPickerHeader(
                  onAddWallet: () {
                    Navigator.of(sheetContext).pop();
                    onAddWallet();
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: _CurrentWalletPreview(wallet: wallet),
              ).marginOnly(bottom: 10.h),
              Padding(
                padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 18.h),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.48,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: wallets.length,
                    separatorBuilder: (_, _) => SizedBox(height: 2.h),
                    itemBuilder: (_, index) {
                      // 当前列表项对应的钱包账户。
                      final item = wallets[index];
                      return _WalletOptionRow(
                        wallet: item,
                        selected: item.id == wallet.id,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onWalletSelected(item);
                        },
                        onRemovePressed: () async {
                          // 移除钱包属于高风险操作，必须先二次确认。
                          final shouldRemove = await _confirmRemoveWallet(
                            sheetContext,
                            item,
                          );
                          if (!shouldRemove || !sheetContext.mounted) {
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                          await onWalletRemoved(item);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 移除钱包前的二次确认弹窗。
Future<bool> _confirmRemoveWallet(
  BuildContext context,
  WalletAccount wallet,
) async {
  // 删除按钮使用错误色，提示这是不可恢复操作。
  final colorScheme = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(S.of(dialogContext).removeWallet),
            content: Text(
              S.of(dialogContext).removeWalletConfirmMessage(wallet.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(S.of(dialogContext).cancel),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(S.of(dialogContext).removeWallet),
              ),
            ],
          );
        },
      ) ??
      false;
}

/// 现代风格的操作按钮（收款/转账）。
///
/// 使用玻璃态效果和柔和的阴影，提供更现代的视觉体验。
