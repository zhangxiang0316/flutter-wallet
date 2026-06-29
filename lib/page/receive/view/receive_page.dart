import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../controller/receive_controller.dart';
import 'widgets/qr_address_panel.dart';
import 'widgets/receive_hero.dart';
import 'widgets/receive_request_panel.dart';
import 'widgets/receive_selector_row.dart';

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
          ReceiveHero(asset: asset, chain: controller.selectedChain),
          SizedBox(height: 12.h),
          ReceiveSelectorRow(
            chains: controller.chains,
            selectedChain: controller.selectedChain,
            assets: controller.assetsForSelectedChain(),
            selectedAsset: asset,
            isLoading: controller.isLoadingAssets,
            onChainSelected: controller.selectChain,
            onAssetSelected: controller.selectAsset,
          ),
          SizedBox(height: 12.h),
          ReceiveRequestPanel(controller: controller),
          SizedBox(height: 12.h),
          ReceiveQrAddressPanel(
            chain: controller.selectedChain,
            address: address,
            qrData: controller.currentQrPayload(),
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
