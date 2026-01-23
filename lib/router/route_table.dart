import 'package:get/get.dart';
import 'package:omnicast/page/event_test_page.dart';
import 'package:omnicast/page/home_page.dart';
import 'package:omnicast/page/http_page.dart';
import 'package:omnicast/page/light_storage_page.dart';
import 'package:omnicast/page/test_page.dart';

class RouteTable {
  static const String event = '/event';
  static const String home = '/home';
  static const String http = '/http';
  static const String lightStorage = '/lightStorage';
  static const String test = '/test';

  static final List<GetPage> pages = [
    GetPage(name: '/event', page: () => EventTestPage()),
    GetPage(name: '/home', page: () => HomePage()),
    GetPage(name: '/http', page: () => HttpPage()),
    GetPage(name: '/lightStorage', page: () => LightStoragePage()),
    GetPage(name: '/test', page: () => TestPage()),
  ];
}
