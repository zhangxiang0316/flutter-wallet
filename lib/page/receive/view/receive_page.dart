import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/wallet_asset.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../controller/receive_controller.dart';

@GetXRoutePage('/receive')
/// 收款页面。
///
/// 支持用户切换链和该链上的币种，并为当前钱包地址生成二维码。页面只展示
/// 公共地址，不涉及私钥读取或签名操作。
// ignore: use_key_in_widget_constructors, must_be_immutable
class ReceivePage extends BaseScaffoldPage<ReceiveController> {
  /// 创建收款页面控制器。
  @override
  ReceiveController generateController() {
    return ReceiveController();
  }

  /// 页面顶部导航栏。
  @override
  PreferredSizeWidget? getAppBar() {
    final colorScheme = Theme.of(context!).colorScheme;
    final dividerColor = colorScheme.outline.withValues(alpha: 0.12);
    return AppBar(
      backgroundColor: Theme.of(context!).cardColor,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: 50.h,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.w),
        onPressed: Get.back,
      ),
      centerTitle: true,
      title: Text(
        S.of(context!).receive,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(
          1 / MediaQuery.of(context!).devicePixelRatio,
        ),
        child: Container(
          height: 1 / MediaQuery.of(context!).devicePixelRatio,
          color: dividerColor,
        ),
      ),
    );
  }

  /// 页面主体。
  ///
  /// 当钱包或币种缺失时展示兜底提示；正常情况下依次展示收款摘要、
  /// 链选择、币种选择、二维码和地址复制区域。
  @override
  Widget? getBody() {
    final wallet = controller.wallet;
    final asset = controller.selectedAsset;
    if (wallet == null || asset == null) {
      return Center(
        child: Text(
          S.of(context!).receiveUnavailable,
          style: TextStyle(fontSize: 13.sp),
        ),
      );
    }

    final address = controller.currentAddress();
    return ColoredBox(
      color: Theme.of(context!).brightness == Brightness.dark
          ? Theme.of(context!).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
        children: [
          _ReceiveHero(asset: asset, chain: controller.selectedChain),
          SizedBox(height: 12.h),
          _ChainSelector(
            selectedChain: controller.selectedChain,
            onSelected: controller.selectChain,
          ),
          SizedBox(height: 12.h),
          _AssetSelector(
            assets: controller.assetsForSelectedChain(),
            selectedAsset: asset,
            isLoading: controller.isLoadingAssets,
            onSelected: controller.selectAsset,
          ),
          SizedBox(height: 12.h),
          _QrAddressPanel(
            chain: controller.selectedChain,
            address: address,
            onCopyPressed: () => _copyAddress(address),
          ),
        ],
      ),
    );
  }

  /// 复制当前收款地址。
  void _copyAddress(String address) {
    if (address.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: address));
    Toast.show(S.current.copied);
  }
}

/// 收款页顶部摘要卡片。
///
/// 用于提示当前选择的币种和网络，让用户在展示二维码前确认收款上下文。
class _ReceiveHero extends StatelessWidget {
  const _ReceiveHero({required this.asset, required this.chain});

  /// 当前收款币种。
  final WalletAsset asset;

  /// 当前收款网络。
  final WalletChain chain;

  @override
  Widget build(BuildContext context) {
    final color = _chainColor(chain);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: _dividerColor(context)),
      ),
      child: Row(
        children: [
          _AssetAvatar(symbol: asset.symbol, color: color, size: 42),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).receiveAsset(asset.symbol),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  chain.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 链选择器。
///
/// 横向展示所有支持链，切换后控制器会同步币种列表和地址。
class _ChainSelector extends StatelessWidget {
  const _ChainSelector({required this.selectedChain, required this.onSelected});

  /// 当前选中的链。
  final WalletChain selectedChain;

  /// 用户选择链后的回调。
  final ValueChanged<WalletChain> onSelected;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: S.of(context).selectReceiveChain,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: WalletChain.values
              .map((chain) {
                final selected = chain == selectedChain;
                final color = _chainColor(chain);
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    labelPadding: EdgeInsets.symmetric(horizontal: 8.w),
                    avatar: _ChainDot(chain: chain, selected: selected),
                    label: Text(
                      chain.name,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? color
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    selectedColor: color.withValues(alpha: 0.12),
                    backgroundColor: Theme.of(context).cardColor,
                    side: BorderSide(
                      color: selected
                          ? color.withValues(alpha: 0.42)
                          : _dividerColor(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    onSelected: (_) => onSelected(chain),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

/// 币种选择器。
///
/// 展示当前链默认资产和用户自定义资产，点击后更新二维码标题和上下文。
class _AssetSelector extends StatelessWidget {
  const _AssetSelector({
    required this.assets,
    required this.selectedAsset,
    required this.isLoading,
    required this.onSelected,
  });

  /// 当前链下可选资产列表。
  final List<WalletAsset> assets;

  /// 当前选中的资产。
  final WalletAsset selectedAsset;

  /// 自定义资产是否仍在加载中。
  final bool isLoading;

  /// 用户选择资产后的回调。
  final ValueChanged<WalletAsset> onSelected;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: S.of(context).selectReceiveAsset,
      trailing: isLoading
          ? SizedBox(
              width: 14.w,
              height: 14.w,
              child: CircularProgressIndicator(strokeWidth: 2.w),
            )
          : null,
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: assets
            .map((asset) {
              final selected = asset.assetKey == selectedAsset.assetKey;
              final color = _chainColor(asset.chain);
              return Material(
                color: selected
                    ? color.withValues(alpha: 0.1)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8.r),
                child: InkWell(
                  onTap: () => onSelected(asset),
                  borderRadius: BorderRadius.circular(8.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: BoxConstraints(minHeight: 40.h),
                    padding: EdgeInsets.fromLTRB(9.w, 7.h, 11.w, 7.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: selected
                            ? color.withValues(alpha: 0.42)
                            : _dividerColor(context),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AssetAvatar(
                          symbol: asset.symbol,
                          color: color,
                          size: 24,
                        ),
                        SizedBox(width: 7.w),
                        Text(
                          asset.symbol,
                          style: TextStyle(
                            color: selected
                                ? color
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.78),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

/// 二维码和地址展示面板。
///
/// 二维码内容直接使用当前链地址。币种本身不改变地址，但会通过页面上下文
/// 提醒用户只向当前网络转入所选资产。
class _QrAddressPanel extends StatelessWidget {
  const _QrAddressPanel({
    required this.chain,
    required this.address,
    required this.onCopyPressed,
  });

  /// 当前二维码对应的链。
  final WalletChain chain;

  /// 当前链的钱包地址。
  final String address;

  /// 复制地址按钮回调。
  final VoidCallback onCopyPressed;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.trim().isNotEmpty;
    final color = _chainColor(chain);
    return _Panel(
      title: S.of(context).receiveQrTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 226.w,
              height: 226.w,
              padding: EdgeInsets.all(13.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: color.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 18.r,
                    offset: Offset(0, 8.h),
                  ),
                ],
              ),
              child: hasAddress
                  ? QrImageView(
                      data: address,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: color,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF111827),
                      ),
                    )
                  : Icon(
                      Icons.qr_code_2_rounded,
                      size: 94.w,
                      color: const Color(0xFF9CA3AF),
                    ),
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            S.of(context).receiveQrTip,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.56),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 13.h),
          _AddressBox(
            label: S.of(context).receiveAddress,
            address: hasAddress ? address : S.of(context).receiveAddressEmpty,
            enabled: hasAddress,
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 44.h,
            child: FilledButton.icon(
              onPressed: hasAddress ? onCopyPressed : null,
              icon: Icon(Icons.copy_rounded, size: 17.w),
              label: Text(
                S.of(context).copyReceiveAddress,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
                disabledForegroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 地址文本展示框。
///
/// 使用 [SelectableText] 允许用户长按选择，同时按钮提供一键复制。
class _AddressBox extends StatelessWidget {
  const _AddressBox({
    required this.label,
    required this.address,
    required this.enabled,
  });

  /// 地址区标题。
  final String label;

  /// 展示的地址或空地址提示。
  final String address;

  /// 当前地址是否可用。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: _dividerColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7.h),
          SelectableText(
            address,
            style: TextStyle(
              color: enabled
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.42),
              fontSize: 12.sp,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 收款页通用面板容器。
///
/// 统一白底、圆角、细边框和标题布局。
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  /// 面板标题。
  final String title;

  /// 面板主体内容。
  final Widget child;

  /// 标题右侧的可选附加组件，例如加载状态。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: _dividerColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

/// 币种头像。
///
/// 使用币种首字母和链色生成轻量标识，避免依赖远程图标。
class _AssetAvatar extends StatelessWidget {
  const _AssetAvatar({
    required this.symbol,
    required this.color,
    required this.size,
  });

  /// 币种简称。
  final String symbol;

  /// 头像主色。
  final Color color;

  /// 头像尺寸。
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = symbol.trim().isEmpty ? '?' : symbol.characters.first;
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: (size * 0.42).sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 链选择器中的圆点标识。
class _ChainDot extends StatelessWidget {
  const _ChainDot({required this.chain, required this.selected});

  /// 对应链。
  final WalletChain chain;

  /// 是否为当前选中链。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = _chainColor(chain);
    return Container(
      width: 18.w,
      height: 18.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.18 : 0.1),
        shape: BoxShape.circle,
      ),
      child: Text(
        _chainLabel(chain),
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 页面通用分隔线颜色。
Color _dividerColor(BuildContext context) {
  return Theme.of(context).colorScheme.outline.withValues(alpha: 0.12);
}

/// 获取收款页中每条链的品牌色。
Color _chainColor(WalletChain chain) {
  switch (chain) {
    case WalletChain.bsc:
      return const Color(0xFFF0B90B);
    case WalletChain.ethereum:
      return const Color(0xFF627EEA);
    case WalletChain.xLayer:
      return const Color(0xFF10B981);
    case WalletChain.solana:
      return const Color(0xFF7C3AED);
    case WalletChain.tron:
      return const Color(0xFFE11D48);
  }
}

/// 获取链在小圆点中的单字母缩写。
String _chainLabel(WalletChain chain) {
  switch (chain) {
    case WalletChain.bsc:
      return 'B';
    case WalletChain.ethereum:
      return 'E';
    case WalletChain.xLayer:
      return 'O';
    case WalletChain.solana:
      return 'S';
    case WalletChain.tron:
      return 'T';
  }
}
