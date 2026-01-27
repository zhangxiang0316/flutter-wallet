// ignore_for_file: constant_identifier_names
import 'package:get/get.dart';
import 'package:omnicast/page/home/view/home_page.dart';
import 'package:omnicast/page/event_test_page.dart';
import 'package:omnicast/page/generate/view/generate_ppt_page.dart';
import 'package:omnicast/page/generate/view/generate_video_page.dart';
import 'package:omnicast/page/generate/view/generate_podcast_page.dart';
import 'package:omnicast/page/test_page.dart';
import 'package:omnicast/page/setting/view/language_page.dart';
import 'package:omnicast/page/setting/view/setting_page.dart';
import 'package:omnicast/page/setting/view/theme_page.dart';
import 'package:omnicast/page/main/view/main_page.dart';
import 'package:omnicast/page/demo_page.dart';
import 'package:omnicast/page/login/view/login_page.dart';
import 'package:omnicast/page/home_test_page.dart';
import 'package:omnicast/page/generate/view/text_to_speech_page.dart';
import 'package:omnicast/page/generate/view/generate_pic_page.dart';
import 'package:omnicast/page/generate/view/voice_cloning_page.dart';
import 'package:omnicast/page/projects/view/projects_page.dart';

class RouteTable {
  static const String home = '/home';
  static const String event = '/event';
  static const String generate_ppt = '/generate_ppt';
  static const String generate_video = '/generate_video';
  static const String generate_podcast = '/generate_podcast';
  static const String test = '/test';
  static const String language = '/language';
  static const String setting = '/setting';
  static const String theme = '/theme';
  static const String main = '/main';
  static const String demo = '/demo';
  static const String login = '/login';
  static const String home_test = '/home_test';
  static const String text_to_speech = '/text_to_speech';
  static const String generate_pic = '/generate_pic';
  static const String voice_cloning = '/voice_cloning';
  static const String projects = '/projects';

  static final List<GetPage> pages = [
    GetPage(name: '/home', page: () => HomePage()),
    GetPage(name: '/event', page: () => EventTestPage()),
    GetPage(name: '/generate_ppt', page: () => GeneratePptPage()),
    GetPage(name: '/generate_video', page: () => GenerateVideoPage()),
    GetPage(name: '/generate_podcast', page: () => GeneratePodcastPage()),
    GetPage(name: '/test', page: () => TestPage()),
    GetPage(name: '/language', page: () => LanguagePage()),
    GetPage(name: '/setting', page: () => SettingPage()),
    GetPage(name: '/theme', page: () => ThemePage()),
    GetPage(name: '/main', page: () => MainPage()),
    GetPage(name: '/demo', page: () => DemoPage()),
    GetPage(name: '/login', page: () => LoginPage()),
    GetPage(name: '/home_test', page: () => HomeTestPage()),
    GetPage(name: '/text_to_speech', page: () => TextToSpeechPage()),
    GetPage(name: '/generate_pic', page: () => GeneratePicPage()),
    GetPage(name: '/voice_cloning', page: () => VoiceCloningPage()),
    GetPage(name: '/projects', page: () => ProjectsPage()),
  ];
}
