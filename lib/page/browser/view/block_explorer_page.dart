import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../controller/block_explorer_controller.dart';

@GetXRoutePage('/blockExplorer')
/// 内嵌区块浏览器页面。
///
/// 用 WebView 展示当前钱包地址的区块浏览器页面，作为应用内交易历史不完整时的
/// 兜底查看方式。
// ignore: use_key_in_widget_constructors, must_be_immutable
class BlockExplorerPage extends BaseScaffoldPage<BlockExplorerController> {
  /// 创建内嵌浏览器控制器。
  @override
  BlockExplorerController generateController() {
    return BlockExplorerController();
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
      toolbarHeight: 52.h,
      leading: IconButton(
        tooltip: S.of(context!).backToWallet,
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.w),
        onPressed: controller.goBack,
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            controller.arguments?.title ?? S.of(context!).blockExplorer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 2.h),
          Text(
            _shortUrl(controller.currentUrl),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.52),
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: S.of(context!).blockExplorerBack,
          onPressed: controller.canGoBack ? controller.goBack : null,
          icon: Icon(Icons.chevron_left_rounded, size: 22.w),
        ),
        IconButton(
          tooltip: S.of(context!).blockExplorerForward,
          onPressed: controller.canGoForward ? controller.goForward : null,
          icon: Icon(Icons.chevron_right_rounded, size: 22.w),
        ),
        PopupMenuButton<_BrowserAction>(
          tooltip: S.of(context!).more,
          icon: Icon(Icons.more_horiz_rounded, size: 22.w),
          onSelected: _handleBrowserAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _BrowserAction.reload,
              child: _BrowserMenuItem(
                icon: Icons.refresh_rounded,
                label: S.of(context).refreshBalance,
              ),
            ),
            PopupMenuItem(
              value: _BrowserAction.copy,
              child: _BrowserMenuItem(
                icon: Icons.copy_rounded,
                label: S.of(context).copyLink,
              ),
            ),
            PopupMenuItem(
              value: _BrowserAction.external,
              child: _BrowserMenuItem(
                icon: Icons.open_in_new_rounded,
                label: S.of(context).openInExternalBrowser,
              ),
            ),
          ],
        ).marginOnly(right: 2.w),
      ],
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
  @override
  Widget? getBody() {
    final webViewController = controller.webViewController;
    if (webViewController == null) {
      return _BrowserErrorState(
        message: controller.errorMessage,
        onReload: controller.reload,
        onOpenExternal: controller.openExternal,
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: webViewController),
        if (controller.errorMessage.isNotEmpty)
          _BrowserErrorState(
            message: controller.errorMessage,
            onReload: controller.reload,
            onOpenExternal: controller.openExternal,
          ),
        if (controller.isLoading)
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: controller.progress <= 0
                  ? null
                  : controller.progress.clamp(0, 100) / 100,
              minHeight: 2.h,
              color: Theme.of(context!).colorScheme.primary,
              backgroundColor: Theme.of(
                context!,
              ).colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
      ],
    );
  }

  void _handleBrowserAction(_BrowserAction action) {
    switch (action) {
      case _BrowserAction.reload:
        controller.reload();
      case _BrowserAction.copy:
        controller.copyUrl();
      case _BrowserAction.external:
        controller.openExternal();
    }
  }

  String _shortUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.host;
  }
}

enum _BrowserAction { reload, copy, external }

class _BrowserMenuItem extends StatelessWidget {
  const _BrowserMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17.w),
        SizedBox(width: 9.w),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _BrowserErrorState extends StatelessWidget {
  const _BrowserErrorState({
    required this.message,
    required this.onReload,
    required this.onOpenExternal,
  });

  final String message;
  final VoidCallback onReload;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.public_off_rounded,
                  color: colorScheme.primary,
                  size: 24.w,
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                message.isEmpty
                    ? S.of(context).blockExplorerOpenFailed
                    : message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12.sp,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onReload,
                    icon: Icon(Icons.refresh_rounded, size: 16.w),
                    label: Text(S.of(context).refreshBalance),
                  ),
                  SizedBox(width: 10.w),
                  FilledButton.icon(
                    onPressed: onOpenExternal,
                    icon: Icon(Icons.open_in_new_rounded, size: 16.w),
                    label: Text(S.of(context).openInExternalBrowser),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
