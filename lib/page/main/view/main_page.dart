import 'package:flutter/material.dart';
import 'package:omnicast/base/base_controller.dart';
import 'package:omnicast/base/base_page.dart';
import 'package:omnicast/page/setting/view/setting_page.dart';

import '../../home/view/home_page.dart';

/// 主页面
class MainPage extends BasePage<MainController> {
  @override
  Widget buildWidget(MainController controller) {
    final ctx = context!;
    return Scaffold(
      body: buildPageView(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        // 自适应宽度，但同时会失去，图标/文字 缩放效果
        currentIndex: controller.bottomSelectedIndex,
        onTap: controller.bottomTap,
        items: buildBottomNavBarItems(),
        // 使用主题背景色，自动适配亮色/暗色模式
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        // 未选中状态下的字体大小
        unselectedFontSize: 14,
        // 选中状态下的颜色 - 使用主题主色
        selectedItemColor: Theme.of(ctx).colorScheme.primary,
        // 未选中状态下的颜色 - 使用主题次要文字颜色
        unselectedItemColor: Theme.of(
          ctx,
        ).colorScheme.onSurface.withValues(alpha: 0.6),
        // 选中状态下的字体大小
        selectedFontSize: 14,
      ),
    );
  }

  @override
  MainController generateController() {
    return MainController();
  }

  List<BottomNavigationBarItem> buildBottomNavBarItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.account_balance_wallet_outlined),
        activeIcon: Icon(Icons.account_balance_wallet),
        label: '钱包',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.settings_outlined),
        activeIcon: Icon(Icons.settings),
        label: '设置',
      ),
    ];
  }

  Widget buildPageView() {
    return PageView(
      physics: const NeverScrollableScrollPhysics(), // 禁止滑动
      controller: controller.pageController,
      onPageChanged: controller.pageChanged,
      children: [HomePage(), SettingPage(showBackButton: false)],
    );
  }
}

class MainController extends BaseController {
  int bottomSelectedIndex = 0;
  PageController? pageController;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: bottomSelectedIndex);
  }

  @override
  void onClose() {
    pageController?.dispose();
    super.onClose();
  }

  void bottomTap(int index) {
    if (index != 0) {}
    bottomSelectedIndex = index;
    pageController?.jumpToPage(index);
    update();
  }

  void pageChanged(int index) {
    bottomSelectedIndex = index;
    update();
  }
}
