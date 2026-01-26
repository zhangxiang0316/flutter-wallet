import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_svg/svg.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_controller.dart';
import 'package:omnicast/base/base_page.dart';

import '../../home/view/home_page.dart';

@GetXRoutePage('/main')
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
        items: buildBottomNavBarItems(ctx),
        // 使用主题背景色，自动适配亮色/暗色模式
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        // 未选中状态下的字体大小
        unselectedFontSize: 14,
        // 选中状态下的颜色 - 使用主题主色
        selectedItemColor: Theme.of(ctx).colorScheme.primary,
        // 未选中状态下的颜色 - 使用主题次要文字颜色
        unselectedItemColor: Theme.of(
          ctx,
        ).colorScheme.onSurface.withOpacity(0.6),
        // 选中状态下的字体大小
        selectedFontSize: 14,
      ),
    );
  }

  @override
  MainController generateController() {
    return MainController();
  }

  List<BottomNavigationBarItem> buildBottomNavBarItems(BuildContext context) {
    // 获取当前主题的颜色
    final unselectedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.6);
    final selectedColor = Theme.of(context).colorScheme.primary;

    return [
      BottomNavigationBarItem(
        icon: SvgPicture.asset(
          'assets/svg/create_no.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(unselectedColor, BlendMode.srcIn),
        ),
        activeIcon: SvgPicture.asset(
          'assets/svg/create.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(selectedColor, BlendMode.srcIn),
        ),
        label: '创建',
      ),
      BottomNavigationBarItem(
        icon: SvgPicture.asset(
          'assets/svg/create_no.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(unselectedColor, BlendMode.srcIn),
        ),
        activeIcon: SvgPicture.asset(
          'assets/svg/create.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(selectedColor, BlendMode.srcIn),
        ),
        label: '项目',
      ),
      BottomNavigationBarItem(
        icon: SvgPicture.asset(
          'assets/svg/create_no.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(unselectedColor, BlendMode.srcIn),
        ),
        activeIcon: SvgPicture.asset(
          'assets/svg/create.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(selectedColor, BlendMode.srcIn),
        ),
        label: '探索',
      ),
    ];
  }

  Widget buildPageView() {
    return PageView(
      physics: const NeverScrollableScrollPhysics(), // 禁止滑动
      controller: controller.pageController,
      onPageChanged: controller.pageChanged,
      children: [
        HomePage(),
        HomePage(),
        HomePage(),
        // MinePage()
      ],
    );
  }
}

class MainController extends BaseController {
  int bottomSelectedIndex = 0;
  PageController? pageController;

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
