import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:omnicast/router/route_table.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:lifecycle/lifecycle.dart';

import 'Initializer.dart';
import 'generated/l10n.dart';
import 'utils/log_util.dart';
import 'utils/storage.dart';

class ThemeController extends GetxController {
  final _storage = Storage();
  static const String _themeKey = 'app_theme_mode';
  final themeMode = ThemeMode.light.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final savedTheme = await _storage.getStorage(_themeKey);
    if (savedTheme != null && savedTheme.isNotEmpty) {
      themeMode.value = _getThemeModeFromString(savedTheme);
    }
  }

  Future<void> switchTheme() async {
    themeMode.value = themeMode.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await _storage.setStorage(_themeKey, themeMode.value.toString());
  }

  ThemeMode _getThemeModeFromString(String theme) {
    if (theme.contains('dark')) {
      return ThemeMode.dark;
    }
    return ThemeMode.light;
  }
}

reportError(FlutterErrorDetails error) {}

void main() async {
  var onError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    onError?.call(details);
    reportError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logE(error);
    return true;
  };
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
      builder: (BuildContext context, Widget? child) => Obx(
        () => GetMaterialApp(
          getPages: RouteTable.pages,
          locale: initialLocale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate, //iOS
          ],
          supportedLocales: S.delegate.supportedLocales,
          navigatorObservers: [
            defaultLifecycleObserver,
            FlutterSmartDialog.observer,
          ],
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: themeController.themeMode.value,
          initialRoute: RouteTable.home,
          routingCallback: (routing) {},
          builder: FlutterSmartDialog.init(),
        ),
      ),
    );
  }
}
