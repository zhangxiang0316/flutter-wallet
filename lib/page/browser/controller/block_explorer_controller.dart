import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';

/// 内嵌区块浏览器页面参数。
///
/// 交易记录页根据当前链和钱包地址生成 URL 后传入，页面只负责加载并展示网页。
class BlockExplorerPageArguments {
  const BlockExplorerPageArguments({required this.url, required this.title});

  /// 区块浏览器地址页 URL。
  final Uri url;

  /// 页面标题，通常使用链名称。
  final String title;
}

/// 内嵌区块浏览器控制器。
///
/// 管理 WebView 加载状态、进度、返回/前进能力，以及复制链接和外部浏览器打开。
class BlockExplorerController extends BaseController {
  /// 路由传入的浏览器参数。
  BlockExplorerPageArguments? arguments;

  /// WebView 控制器。初始化失败或参数缺失时为空。
  WebViewController? webViewController;

  /// 当前加载进度，范围 0-100。
  int progress = 0;

  /// 是否正在加载网页。
  bool isLoading = true;

  /// 当前 WebView 是否可以后退。
  bool canGoBack = false;

  /// 当前 WebView 是否可以前进。
  bool canGoForward = false;

  /// WebView 加载失败文案。
  String errorMessage = '';

  /// 当前页面 URL 文本，用于展示和复制。
  String currentUrl = '';

  @override
  void onInit() {
    super.onInit();
    final value = Get.arguments;
    if (value is BlockExplorerPageArguments) {
      arguments = value;
      currentUrl = value.url.toString();
      _initWebView(value.url);
    } else {
      isLoading = false;
      errorMessage = S.current.blockExplorerUnavailable;
    }
  }

  /// 初始化 WebView 并加载目标地址。
  void _initWebView(Uri url) {
    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            progress = value;
            isLoading = value < 100;
            update();
          },
          onPageStarted: (url) {
            currentUrl = url;
            errorMessage = '';
            isLoading = true;
            progress = 0;
            update();
          },
          onPageFinished: (url) async {
            currentUrl = url;
            isLoading = false;
            progress = 100;
            await _syncNavigationState();
          },
          onWebResourceError: (error) {
            isLoading = false;
            errorMessage = error.description;
            update();
          },
        ),
      )
      ..loadRequest(url);
  }

  /// WebView 后退；不能后退时退出当前页面。
  Future<void> goBack() async {
    final controller = webViewController;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      await _syncNavigationState();
      return;
    }
    Get.back();
  }

  /// WebView 前进。
  Future<void> goForward() async {
    final controller = webViewController;
    if (controller == null || !await controller.canGoForward()) return;
    await controller.goForward();
    await _syncNavigationState();
  }

  /// 刷新当前网页。
  Future<void> reload() async {
    await webViewController?.reload();
  }

  /// 复制当前网页链接。
  Future<void> copyUrl() async {
    final url = currentUrl.trim();
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    Toast.show(S.current.copied);
  }

  /// 用系统浏览器打开当前链接，作为内嵌页面加载失败时的兜底操作。
  Future<void> openExternal() async {
    final uri = Uri.tryParse(currentUrl);
    if (uri == null) {
      Toast.show(S.current.blockExplorerOpenFailed);
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        Toast.show(S.current.blockExplorerOpenFailed);
      }
    } catch (_) {
      Toast.show(S.current.blockExplorerOpenFailed);
    }
  }

  Future<void> _syncNavigationState() async {
    final controller = webViewController;
    if (controller == null) return;
    canGoBack = await controller.canGoBack();
    canGoForward = await controller.canGoForward();
    update();
  }
}
