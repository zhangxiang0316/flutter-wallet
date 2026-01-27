import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:lifecycle/lifecycle.dart';

import 'Initializer.dart';
import 'common/theme/app_theme_extension.dart';
import 'generated/l10n.dart';
import 'generated/route_table.dart';
import 'utils/log_util.dart';
import 'utils/storage.dart';

// 应用主题切换与持久化控制器
class ThemeController extends GetxController {
  final _storage = Storage();
  static const String _themeKey = 'app_theme_mode';
  final themeMode = ThemeMode.light.obs;

  @override
  void onInit() {
    super.onInit();
    // 启动时加载已保存的主题模式
    _loadSavedTheme();
  }

  // 从本地存储恢复主题模式
  Future<void> _loadSavedTheme() async {
    final savedTheme = await _storage.getStorage(_themeKey);
    if (savedTheme != null && savedTheme.isNotEmpty) {
      themeMode.value = _getThemeModeFromString(savedTheme);
    }
  }

  // 切换主题并持久化
  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _storage.setStorage(_themeKey, mode.toString());
  }

  // 切换主题并持久化 (Legacy)
  Future<void> switchTheme() async {
    if (themeMode.value == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }

  // 将字符串还原为 ThemeMode
  ThemeMode _getThemeModeFromString(String theme) {
    if (theme.contains('dark')) {
      return ThemeMode.dark;
    }
    if (theme.contains('system')) {
      return ThemeMode.system;
    }
    return ThemeMode.light;
  }
}

// 统一上报 Flutter 错误
reportError(FlutterErrorDetails error) {}

void main() async {
  var onError = FlutterError.onError;
  // 统一捕获 Flutter 框架错误
  FlutterError.onError = (FlutterErrorDetails details) {
    onError?.call(details);
    reportError(details);
  };
  // 统一捕获异步未处理错误
  PlatformDispatcher.instance.onError = (error, stack) {
    logE(error);
    return true;
  };
  // 业务初始化
  await Initializer.init();

  // 初始化主题控制器
  Get.put(ThemeController());

  // 加载保存的语言设置
  final savedLanguage = await Storage().getStorage('app_language');
  Locale? initialLocale;
  if (savedLanguage != null && savedLanguage.isNotEmpty) {
    initialLocale = Locale(savedLanguage);
  }

  runApp(MyApp(initialLocale: initialLocale));
}

// 应用入口 Widget
class MyApp extends StatelessWidget {
  final Locale? initialLocale;

  const MyApp({Key? key, this.initialLocale}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPaintSizeEnabled = false;
    final themeController = Get.find<ThemeController>();
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      // 根据响应式主题状态重建 MaterialApp
      builder: (BuildContext context, Widget? child) => Obx(
        () => GetMaterialApp(
          // 路由表配置
          getPages: RouteTable.pages,
          // 初始语言
          locale: initialLocale,
          // 本地化代理
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate, //iOS
          ],
          // 语言支持范围
          supportedLocales: S.delegate.supportedLocales,
          // 导航观察器（生命周期与弹窗）
          navigatorObservers: [
            defaultLifecycleObserver,
            FlutterSmartDialog.observer,
          ],
          // 关闭调试角标
          debugShowCheckedModeBanner: false,
          // 亮色主题
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            // 页面背景色 - 浅灰色
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            // 卡片/组件背景色 - 白色
            cardColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
              // 主色调 - 用于按钮、选中状态等
              primary: Colors.blue,
              // 主色调上的文字颜色
              onPrimary: Colors.white,
              // 次要色 - 用于辅助元素
              secondary: Colors.blueAccent,
              // 次要色上的文字颜色
              onSecondary: Colors.white,
              // 表面颜色 - 用于卡片、对话框等
              surface: Colors.white,
              // 表面上的文字颜色
              onSurface: Colors.black87,
              // 错误颜色
              error: Colors.red,
              // 错误颜色上的文字
              onError: Colors.white,
            ),
            // 底部导航栏主题
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              selectedLabelStyle: TextStyle(fontSize: 14),
              unselectedLabelStyle: TextStyle(fontSize: 14),
            ),
            // AppBar 主题
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
            ),
            // 自定义主题扩展
            extensions: <ThemeExtension<dynamic>>[
              AppThemeExtension.light(),
            ],
          ),
          // 暗色主题
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            // 页面背景色 - 深色
            scaffoldBackgroundColor: const Color(0xFF121212),
            // 卡片/组件背景色 - 稍浅的深色
            cardColor: const Color(0xFF1E1E1E),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
              // 主色调 - 用于按钮、选中状态等
              primary: Colors.blue,
              // 主色调上的文字颜色
              onPrimary: Colors.black,
              // 次要色 - 用于辅助元素
              secondary: Colors.blue,
              // 次要色上的文字颜色
              onSecondary: Colors.black,
              // 表面颜色 - 用于卡片、对话框等
              surface: const Color(0xFF1E1E1E),
              // 表面上的文字颜色
              onSurface: Colors.white70,
              // 错误颜色
              error: Colors.redAccent,
              // 错误颜色上的文字
              onError: Colors.black,
            ),
            // 底部导航栏主题
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFF1E1E1E),
              selectedItemColor: Colors.blueAccent,
              unselectedItemColor: Colors.grey,
              selectedLabelStyle: TextStyle(fontSize: 14),
              unselectedLabelStyle: TextStyle(fontSize: 14),
            ),
            // AppBar 主题
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white70,
              elevation: 0,
            ),
            // 自定义主题扩展
            extensions: <ThemeExtension<dynamic>>[
              AppThemeExtension.dark(),
            ],
          ),
          // 主题模式由控制器驱动
          themeMode: themeController.themeMode.value,
          // 初始路由
          initialRoute: RouteTable.main,
          // 路由回调
          routingCallback: (routing) {},
          // 弹窗初始化
          builder: FlutterSmartDialog.init(),
        ),
      ),
    );
  }
}
