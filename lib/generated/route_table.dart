// ignore_for_file: constant_identifier_names
import 'package:get/get.dart';
import 'package:omnicast/page/home/view/home_page.dart';
import 'package:omnicast/page/setting/view/language_page.dart';
import 'package:omnicast/page/setting/view/setting_page.dart';
import 'package:omnicast/page/setting/view/theme_page.dart';
import 'package:omnicast/page/main/view/main_page.dart';
import 'package:omnicast/page/transfer/view/transfer_page.dart';

class RouteTable {
  static const String home = '/home';
  static const String language = '/language';
  static const String setting = '/setting';
  static const String theme = '/theme';
  static const String main = '/main';
  static const String transfer = '/transfer';

  static final List<GetPage> pages = [
    GetPage(name: '/home', page: () => HomePage()),
    GetPage(name: '/language', page: () => LanguagePage()),
    GetPage(name: '/setting', page: () => SettingPage()),
    GetPage(name: '/theme', page: () => ThemePage()),
    GetPage(name: '/main', page: () => MainPage()),
    GetPage(name: '/transfer', page: () => TransferPage()),
  ];
}
