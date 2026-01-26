// ignore_for_file: constant_identifier_names
import 'package:get/get.dart';
import 'package:omnicast/page/home/view/home_page.dart';
import 'package:omnicast/page/event_test_page.dart';
import 'package:omnicast/page/test_page.dart';
import 'package:omnicast/page/demo_page.dart';
import 'package:omnicast/page/main/view/main_page.dart';
import 'package:omnicast/page/home_test_page.dart';
import 'package:omnicast/page/setting/view/setting_page.dart';
import 'package:omnicast/page/setting/view/language_page.dart';
import 'package:omnicast/page/setting/view/theme_page.dart';

class RouteTable {
  static const String home = '/home';
  static const String event = '/event';
  static const String test = '/test';
  static const String demo = '/demo';
  static const String main = '/main';
  static const String home_test = '/home_test';
  static const String setting = '/setting';
  static const String language = '/language';
  static const String theme = '/theme';

  static final List<GetPage> pages = [
    GetPage(name: '/home', page: () => HomePage()),
    GetPage(name: '/event', page: () => EventTestPage()),
    GetPage(name: '/test', page: () => TestPage()),
    GetPage(name: '/demo', page: () => DemoPage()),
    GetPage(name: '/main', page: () => MainPage()),
    GetPage(name: '/home_test', page: () => HomeTestPage()),
    GetPage(name: '/setting', page: () => SettingPage()),
    GetPage(name: '/language', page: () => LanguagePage()),
    GetPage(name: '/theme', page: () => ThemePage()),
  ];
}
